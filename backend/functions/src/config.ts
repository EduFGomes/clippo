/**
 * Configuração compartilhada por todas as funções.
 *
 * REGION precisa ser a MESMA região do Firestore e do Storage.
 * A região do Firestore não muda depois de criada.
 * Decidido em 13/10/2026: us-east1 no MVP, pela cota gratuita do Storage.
 */
export const REGION = "us-east1";

/** Limite de instâncias simultâneas por função: protege contra gasto inesperado. */
export const MAX_INSTANCES = 10;
