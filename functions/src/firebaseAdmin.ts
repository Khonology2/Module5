import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const adminApp = getApps().length > 0 ? getApps()[0]! : initializeApp();

const firestore = getFirestore(adminApp);

export { adminApp, firestore };
