/**
 * Aplica a política de senha do Clippo (PASSWORD_POLICY em src/users/validation.ts) ao
 * Firebase Auth de um projeto. É a metade "servidor" da regra de senha nova (AGENTS.md, regra 0).
 *
 * Rode a partir de backend/functions, depois do `npm run build`:
 *
 *   Emulator:      FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node scripts/apply-password-policy.mjs demo-clippo
 *   Projeto real:  node scripts/apply-password-policy.mjs clippo-dev
 *                  (precisa de `gcloud auth application-default login` com acesso ao projeto
 *                  e do Identity Platform ligado; só com o pedido explícito do grupo)
 *
 * Seguro repetir: grava a mesma configuração.
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

import { PASSWORD_POLICY } from "../lib/users/validation.js";

const projectId = process.argv[2];
if (!projectId) {
  console.error("Diga o projeto: node scripts/apply-password-policy.mjs <projeto>");
  process.exit(1);
}

initializeApp({ projectId });
const config = await getAuth().projectConfigManager().updateProjectConfig({
  passwordPolicyConfig: PASSWORD_POLICY,
});
console.log(`Política de senha aplicada em ${projectId}:`, JSON.stringify(config.passwordPolicyConfig));
