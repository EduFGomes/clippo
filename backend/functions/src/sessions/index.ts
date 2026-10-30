/**
 * Domínio: sessões.
 *
 * Pronto:
 * - saveSession: chamada no "Salvar sessão" → valida, grava a sessão e os highlights
 *   numa transação e devolve onde cada vídeo deve ser enviado (D15).
 *
 * 🟡 Falta: a conferência de R10 (participantes são amigos do dono) está em
 *   `validation.ts › participantsAreFriends` e só passa a valer quando `Friendship` existir.
 */
export { saveSession } from "./saveSession";
