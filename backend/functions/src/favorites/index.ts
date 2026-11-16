/**
 * Domínio: favoritos (R18–R22 em docs/produto.md; D19 em docs/arquitetura.md).
 *
 * Um participante favorita um lance e ele aparece no perfil dele; os amigos assistem, curtem e
 * comentam, sem precisar ter participado da sessão.
 *
 * - favoriteHighlight / unfavoriteHighlight: chamáveis, favoritar e desfazer.
 * - likePost: chamável, curtir e descurtir.
 * - addComment / deleteComment: chamáveis, comentar e apagar o comentário.
 * - onHighlightDeleted / onSessionParticipantsChanged: gatilhos que apagam o favorito junto (R21).
 */
export { favoriteHighlight } from "./favoriteHighlight";
export { unfavoriteHighlight } from "./unfavoriteHighlight";
export { likePost } from "./likePost";
export { addComment, deleteComment } from "./comments";
export { onHighlightDeleted, onSessionParticipantsChanged } from "./triggers";
