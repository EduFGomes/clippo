/**
 * Funções do domínio de highlights (trechos de 30 s salvos pelo gesto \ o /).
 *
 * - onVideoUploaded: gatilho do Storage que confere o MP4 enviado e marca o
 *   highlight como `uploaded` (R13, D15).
 * - renameHighlight: o dono da sessão troca o nome de um lance (nasce "Lance N").
 * - (a fazer) onHighlightCreated: avisa os participantes por push (R16).
 */
export { onVideoUploaded } from "./onVideoUploaded";
export { renameHighlight } from "./renameHighlight";
