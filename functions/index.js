const {randomInt} = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {FieldValue, Timestamp, getFirestore} = require("firebase-admin/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {HttpsError, onCall} = require("firebase-functions/v2/https");

initializeApp();
setGlobalOptions({region: "asia-northeast3", maxInstances: 10});

const db = getFirestore();
const inviteCharacters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function requireUser(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  return request.auth;
}

function createInviteCode() {
  return Array.from(
    {length: 6},
    () => inviteCharacters[randomInt(inviteCharacters.length)],
  ).join("");
}

exports.createFridgeInvite = onCall(async (request) => {
  const auth = requireUser(request);
  const userSnapshot = await db.collection("users").doc(auth.uid).get();
  const fridgeId = userSnapshot.get("activeFridgeId");
  if (!fridgeId) {
    throw new HttpsError("failed-precondition", "활성 냉장고가 없습니다.");
  }

  const memberSnapshot = await db
    .collection("fridges")
    .doc(fridgeId)
    .collection("members")
    .doc(auth.uid)
    .get();
  if (memberSnapshot.get("role") !== "owner") {
    throw new HttpsError("permission-denied", "냉장고 소유자만 초대할 수 있습니다.");
  }

  const expiresAt = Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000);
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const code = createInviteCode();
    try {
      await db.collection("fridgeInvites").doc(code).create({
        fridgeId,
        createdBy: auth.uid,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt,
        maxUses: 10,
        usedCount: 0,
        revoked: false,
      });
      return {code, expiresAt: expiresAt.toMillis()};
    } catch (error) {
      if (error.code !== 6 && error.code !== "already-exists") throw error;
    }
  }
  throw new HttpsError("resource-exhausted", "초대 코드를 만들지 못했습니다.");
});

exports.joinFridgeWithCode = onCall(async (request) => {
  const auth = requireUser(request);
  const code = String(request.data?.code ?? "").trim().toUpperCase();
  if (!/^[A-HJ-NP-Z2-9]{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "6자리 초대 코드를 확인해 주세요.");
  }

  const inviteReference = db.collection("fridgeInvites").doc(code);
  const userReference = db.collection("users").doc(auth.uid);

  const fridgeId = await db.runTransaction(async (transaction) => {
    const inviteSnapshot = await transaction.get(inviteReference);
    if (!inviteSnapshot.exists) {
      throw new HttpsError("not-found", "유효하지 않은 초대 코드입니다.");
    }

    const invite = inviteSnapshot.data();
    if (invite.revoked === true || invite.expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError("deadline-exceeded", "만료된 초대 코드입니다.");
    }
    if ((invite.usedCount ?? 0) >= (invite.maxUses ?? 1)) {
      throw new HttpsError("resource-exhausted", "사용 횟수가 끝난 초대 코드입니다.");
    }

    const targetFridgeId = invite.fridgeId;
    const memberReference = db
      .collection("fridges")
      .doc(targetFridgeId)
      .collection("members")
      .doc(auth.uid);
    const memberSnapshot = await transaction.get(memberReference);

    if (!memberSnapshot.exists) {
      transaction.set(memberReference, {
        role: "member",
        displayName: auth.token.name ?? null,
        email: auth.token.email ?? null,
        joinedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(inviteReference, {
        usedCount: FieldValue.increment(1),
      });
    }

    transaction.set(
      userReference,
      {
        activeFridgeId: targetFridgeId,
        fridgeIds: FieldValue.arrayUnion(targetFridgeId),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return targetFridgeId;
  });

  return {fridgeId};
});
