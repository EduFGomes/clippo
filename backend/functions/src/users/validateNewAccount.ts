/**
 * validateNewAccount — função de BLOQUEIO do Firebase Auth (roda antes de a conta ser criada).
 *
 * Por que existe: o Firebase Auth aceita e-mails como "nome@g". O app já valida antes de
 * chamar o Auth, mas a regra do projeto é que nada chega ao Auth, ao Firestore ou ao Storage
 * sem passar por validação no servidor também. Se o e-mail não passa, a conta não é criada
 * e o app recebe o erro.
 *
 * Contas sem e-mail (telefone, anônimas) não são usadas no Clippo e também são recusadas.
 *
 * 🟡 No projeto real, funções de bloqueio exigem o Firebase Authentication com Identity Platform
 * (ver docs/arquitetura.md › Decisões em aberto). No Emulator funciona sem nada a mais.
 */
import { HttpsError, beforeUserCreated } from "firebase-functions/v2/identity";

import { ValidationError, normalizeEmail } from "./validation";

export const validateNewAccount = beforeUserCreated((event) => {
  try {
    normalizeEmail(event.data?.email);
  } catch (e) {
    if (e instanceof ValidationError) {
      throw new HttpsError("invalid-argument", e.message);
    }
    throw e;
  }
});
