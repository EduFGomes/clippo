/**
 * Domínio: usuários e conta.
 *
 * Pronto:
 * - completeProfile: chamada pelo app depois de criar a conta → cria o perfil e reserva o @usuário.
 * - updateProfile: tela Perfil → muda nome e/ou @usuário e atualiza as cópias em amizades e sessões.
 * - validateNewAccount: bloqueio do Auth → recusa a conta se o e-mail não for válido.
 * - deleteMyAccount: chamada pelo app → apaga a conta e os dados da pessoa (LGPD).
 */
export { completeProfile } from "./completeProfile";
export { updateProfile } from "./updateProfile";
export { validateNewAccount } from "./validateNewAccount";
export { deleteMyAccount } from "./deleteMyAccount";
