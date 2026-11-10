/**
 * Domínio: amigos (D16 em docs/arquitetura.md › Amigos).
 *
 * Pronto:
 * - sendFriendRequest: "Adicionar amigo" pelo @ → cria o pedido (ou aceita, se a outra
 *   pessoa já tinha pedido).
 * - acceptFriendRequest: quem recebeu aceita → amizade mútua (R15).
 * - removeFriend: cancela, recusa ou desfaz a amizade.
 */
export { sendFriendRequest } from "./sendFriendRequest";
export { acceptFriendRequest } from "./acceptFriendRequest";
export { removeFriend } from "./removeFriend";
