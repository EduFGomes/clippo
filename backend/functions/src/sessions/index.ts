/**
 * Domínio: sessões.
 *
 * - saveSession: chamada no "Salvar sessão" → valida (inclusive R10, participantes são
 *   amigos do dono), grava a sessão e os highlights numa transação e devolve onde cada
 *   vídeo deve ser enviado (D15).
 * - updateSession: o dono muda nome, local e participantes depois de salva (R12).
 * - leaveSession: um participante sai da sessão (🟡 a confirmar com o grupo).
 * - requestSessionMerge / acceptSessionMerge / cancelSessionMerge: juntar duas sessões
 *   do mesmo jogo num hub só (D18).
 */
export { saveSession } from "./saveSession";
export { updateSession } from "./updateSession";
export { leaveSession } from "./leaveSession";
export { acceptSessionMerge, cancelSessionMerge, requestSessionMerge } from "./merge";
