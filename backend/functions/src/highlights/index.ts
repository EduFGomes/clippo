/**
 * Domínio: highlights.
 *
 * Planejado (rascunho, depende do modelo de dados):
 * - onHighlightCreated: highlight criado no Firestore → atualiza contadores
 *   (perfil, sessão, "sessões juntos" R16) e avisa os participantes por push.
 * - onVideoUploaded: vídeo chegou no Storage → confere tamanho/formato e
 *   marca o highlight como "enviado" (R13).
 *
 * Lembrete: gatilhos podem rodar mais de uma vez para o mesmo evento.
 * Escreva de forma idempotente (rodar de novo não pode somar duas vezes).
 */
export {};
