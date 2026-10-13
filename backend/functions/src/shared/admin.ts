/**
 * Acesso ao Firebase com permissão de administrador (Admin SDK).
 *
 * Só as Cloud Functions usam isto. O Admin SDK IGNORA as Security Rules,
 * então toda função que grava dados é responsável por validar o que grava.
 * Nunca copie credenciais do Admin SDK para o app.
 */
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

if (getApps().length === 0) {
  initializeApp();
}

export const db = () => getFirestore();
export const bucket = () => getStorage().bucket();
