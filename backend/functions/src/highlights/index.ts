/**
 * Funções do domínio de highlights (trechos de 30 s salvos pelo gesto \ o /).
 *
 * - onVideoUploaded: gatilho do Storage que confere o MP4 enviado e marca o
 *   highlight como `uploaded` (R13, D15).
 * - (a fazer) onHighlightCreated: avisa os participantes por push (R16).
 */
export { onVideoUploaded } from "./onVideoUploaded";
