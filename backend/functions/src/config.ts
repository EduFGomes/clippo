/**
 * Configuração compartilhada por todas as funções.
 *
 * Regiões (D4, decidido pelo grupo em 09/11/2026; antes era tudo em us-east1):
 * - REGION: Firestore e todas as funções, em São Paulo, para o app responder rápido.
 *   A região do Firestore não muda depois de criada.
 * - STORAGE_REGION: só o bucket do Storage fica nos EUA, porque a cota gratuita
 *   do Cloud Storage só existe em us-central1, us-east1 e us-west1.
 *   Gatilhos do Storage (ex.: onVideoUploaded) precisam rodar na MESMA região do
 *   bucket, então usam STORAGE_REGION.
 */
export const REGION = "southamerica-east1";
export const STORAGE_REGION = "us-east1";

/** Limite de instâncias simultâneas por função: protege contra gasto inesperado. */
export const MAX_INSTANCES = 10;
