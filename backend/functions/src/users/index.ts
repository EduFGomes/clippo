/**
 * Domínio: usuários e conta.
 *
 * Pronto:
 * - completeProfile: chamada pelo app depois de criar a conta → cria o perfil e reserva o @usuário.
 * - validateNewAccount: bloqueio do Auth → recusa a conta se o e-mail não for válido.
 *
 * Planejado (rascunho):
 * - deleteMyAccount: chamada pelo app → apaga ou anonimiza os dados da pessoa (LGPD).
 */
export { completeProfile } from "./completeProfile";
export { validateNewAccount } from "./validateNewAccount";
