import { firestore } from '../firebaseAdmin';

export async function findUserIdByEmail(email: string): Promise<string | null> {
  const normalized = email.trim().toLowerCase();
  if (normalized.length === 0) return null;

  const directSnap = await firestore
    .collection('users')
    .where('email', '==', normalized)
    .limit(1)
    .get();
  if (!directSnap.empty) {
    return directSnap.docs[0]!.id;
  }

  const exactCaseSnap = await firestore
    .collection('users')
    .where('email', '==', email.trim())
    .limit(1)
    .get();
  if (!exactCaseSnap.empty) {
    return exactCaseSnap.docs[0]!.id;
  }

  return null;
}
