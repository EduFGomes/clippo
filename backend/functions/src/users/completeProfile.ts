/**
 * completeProfile — função CHAMÁVEL (o app chama depois de criar a conta no Auth).
 *
 * Por que chamável e não gatilho: só a chamável recebe o que a pessoa digitou
 * (nome, @usuário, data de nascimento). Um gatilho de "conta criada" só veria uid e e-mail.
 *
 * O que faz, numa transação (ou grava tudo, ou nada):
 *   usernames/{username}  → trava que garante @ único (o ID do documento não se repete)
 *   users/{uid}           → perfil público (amigos leem): nome, @, foto, contadores
 *   userPrivate/{uid}     → dados que só o dono lê: data de nascimento
 *
 * O e-mail NÃO é gravado aqui: ele fica só no Firebase Auth.
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db } from "../shared/admin";
import {
  ValidationError,
  normalizeBirthDate,
  normalizeName,
  normalizeUsername,
} from "./validation";

export interface CompleteProfileRequest {
  name: string;
  username: string;
  /** AAAA-MM-DD */
  birthDate: string;
}

export interface CompleteProfileResponse {
  username: string;
}

export const completeProfile = onCall<CompleteProfileRequest, Promise<CompleteProfileResponse>>(
  async (request) => {

    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para continuar.");
    }

    let name: string;
    let username: string;
    let birthDate: string;
    try {
      name = normalizeName(request.data?.name);
      username = normalizeUsername(request.data?.username);
      birthDate = normalizeBirthDate(request.data?.birthDate);
    } catch (e) {
      if (e instanceof ValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: e.field });
      }
      throw e;
    }

    const photoUrl = typeof request.auth?.token.picture === "string" ? request.auth.token.picture : null;

    const userRef = db().doc(`users/${uid}`);
    const usernameRef = db().doc(`usernames/${username}`);
    const privateRef = db().doc(`userPrivate/${uid}`);

    // 3. Transação: lê, decide e grava como uma coisa só.
    await db().runTransaction(async (tx) => {
      const [userSnap, usernameSnap] = await Promise.all([tx.get(userRef), tx.get(usernameRef)]);

      if (userSnap.exists) {
        // Idempotente: chamar de novo com o mesmo @ não é erro (ex.: o app repetiu a chamada).
        if (userSnap.get("username") === username) return;
        throw new HttpsError("already-exists", "Seu perfil já foi criado.");
      }
      if (usernameSnap.exists && usernameSnap.get("uid") !== uid) {
        throw new HttpsError("already-exists", "Esse nome de usuário já está em uso.", {
          field: "username",
        });
      }

      const now = FieldValue.serverTimestamp();
      tx.set(usernameRef, { uid, createdAt: now });
      tx.set(userRef, {
        name,
        username,
        photoUrl,
        stats: { sessions: 0, highlights: 0, friends: 0 },
        createdAt: now,
      });
      tx.set(privateRef, { birthDate, createdAt: now });
    });

    return { username };
  },
);
