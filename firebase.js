import { initializeApp } from "firebase/app";

const firebaseConfig = {
  apiKey: "AIzaSyB9wEmGpWnNfB03qNSsr2luFRZ6Fmo5e5Y",
  authDomain: "pdh-v2.firebaseapp.com",
  projectId: "pdh-v2",
  storageBucket: "pdh-v2.firebasestorage.app",
  messagingSenderId: "638896632756",
  appId: "1:638896632756:web:6df76beff446f75ee378e1"
};

const app = initializeApp(firebaseConfig);
export default app;
export { app };
