/**
 * Ponto de entrada das Cloud Functions do Clippo.
 *
 * Convenção: cada domínio tem a própria pasta e exporta suas funções no
 * próprio index.ts. Este arquivo só aplica as opções globais e reexporta.
 * Assim, cada pessoa trabalha na pasta do seu domínio sem conflitar aqui.
 */
import { setGlobalOptions } from "firebase-functions/v2";
import { MAX_INSTANCES, REGION } from "./config";

setGlobalOptions({ region: REGION, maxInstances: MAX_INSTANCES });

export * from "./users";
export * from "./friends";
export * from "./sessions";
export * from "./highlights";
export * from "./maintenance";
