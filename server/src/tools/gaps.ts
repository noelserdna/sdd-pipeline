import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { getNextStepHint } from "../hints.js";

// ---------------------------------------------------------------------------
// Types for gap-analysis.json
// ---------------------------------------------------------------------------

interface GapFinding {
  id: string;
  category: "missing" | "orphan" | "mismatch";
  severity: string;
  artifact?: string;
  description: string;
  recommendation?: string;
  source?: string;
  target?: string;
}

interface GapAnalysis {
  generatedAt: string;
  projectName?: string;
  summary: {
    total: number;
    missing: number;
    orphan: number;
    mismatch: number;
  };
  findings: GapFinding[];
}

// ---------------------------------------------------------------------------
// Types for the shape the skill actually writes (sdd-gap-analysis-v1)
// ---------------------------------------------------------------------------

/**
 * `sdd-gap-detector` escribe ESTA forma, no la de arriba.
 *
 * Los mismos datos con otra estructura: los hallazgos no vienen en un array
 * plano con `category`, sino repartidos en `endpoints.{missing,orphan,mismatch}`
 * y `bddCoverage.missing`. Leerla como si fuera la canonica hacia que
 * `data.findings` fuera `undefined`, y las tres rutas de `executeGaps` —el
 * filtro, `detail` y `summary`— lanzaban TypeError.
 */
interface EndpointEspecificado {
  id?: string;
  method?: string;
  path?: string;
  specFile?: string;
}

interface EndpointHuerfano {
  method?: string;
  path?: string;
  codeFile?: string;
  handler?: string;
  line?: number;
}

interface EndpointDesajustado {
  id?: string;
  issue?: string;
  specFile?: string;
  codeFile?: string;
}

interface GapAnalysisV1 {
  $schema?: string;
  generatedAt: string;
  projectFramework?: string;
  endpoints?: {
    specified?: EndpointEspecificado[];
    implemented?: unknown[];
    missing?: EndpointEspecificado[];
    orphan?: EndpointHuerfano[];
    mismatch?: EndpointDesajustado[];
  };
  bddCoverage?: {
    totalScenarios?: number;
    withTestFiles?: number;
    withoutTestFiles?: number;
    missing?: string[];
  };
  statistics?: Record<string, number>;
}

/** El resultado de normalizar cualquiera de las dos formas conocidas. */
interface AnalisisNormalizado {
  generatedAt: string;
  projectName: string | null;
  projectFramework: string | null;
  summary: { total: number; missing: number; orphan: number; mismatch: number };
  findings: GapFinding[];
  /** Cuantos de los `missing` son endpoints y cuantos escenarios BDD. */
  desglose: { endpoints: number; escenariosBdd: number };
  /** Las estadisticas tal y como las escribio el generador, sin reinterpretar. */
  estadisticasOrigen: Record<string, number> | null;
}

// ---------------------------------------------------------------------------
// Tool definition
// ---------------------------------------------------------------------------

export const GAPS_TOOL = {
  name: "sdd_gaps",
  description:
    "Read gap analysis results from .sdd/gap-analysis.json. Filters by category (missing, orphan, mismatch) and returns summary or detailed findings. Use after running /sdd-gap-detector.",
  inputSchema: {
    type: "object" as const,
    properties: {
      category: {
        type: "string",
        description:
          'Filter by gap category: "missing" | "orphan" | "mismatch" | "all" (default: "all")',
      },
      format: {
        type: "string",
        description:
          'Output format: "summary" (stats + top issues) or "detail" (all findings). Default: "summary"',
      },
    },
  },
};

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------

interface GapsArgs {
  category?: "missing" | "orphan" | "mismatch" | "all";
  format?: "summary" | "detail";
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Walk up from startDir looking for `.sdd/gap-analysis.json`.
 */
function findGapAnalysisFile(startDir: string): string | null {
  let dir = startDir;
  for (let i = 0; i < 6; i++) {
    const candidate = join(dir, ".sdd", "gap-analysis.json");
    if (existsSync(candidate)) return candidate;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function loadGapAnalysis(cwd?: string): Record<string, unknown> | null {
  const searchDir = cwd ?? process.cwd();
  const filePath = findGapAnalysisFile(searchDir);
  if (!filePath) return null;

  try {
    const raw = readFileSync(filePath, "utf-8");
    // Se devuelve crudo a proposito: cual de las dos formas conocidas es lo
    // decide `executeGaps`, y afirmar aqui `as GapAnalysis` era justamente lo
    // que hacia que el fallo apareciera mas tarde y como TypeError.
    return JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return null;
  }
}

/**
 * El identificador de un huerfano, derivado de lo que lo identifica: su metodo y
 * su ruta.
 *
 * **No del indice del array.** Un `ORPHAN-0` cambiaria de significado en cuanto
 * se anadiera o quitara una ruta por delante, de modo que el mismo hallazgo
 * tendria identificadores distintos entre ejecuciones y dos hallazgos distintos
 * compartirian el suyo. Un identificador que se mueve solo no sirve para
 * seguirle la pista a nada.
 */
function idDeHuerfano(e: EndpointHuerfano): string {
  const metodo = (e.method ?? "ANY").toUpperCase();
  const ruta = e.path ?? e.codeFile ?? "desconocida";
  return `ORPHAN-${metodo}-${ruta}`;
}

function esFormaV1(d: Record<string, unknown>): boolean {
  return (
    d.$schema === "sdd-gap-analysis-v1" ||
    typeof d.endpoints === "object" ||
    typeof d.bddCoverage === "object"
  );
}

function esFormaCanonica(d: Record<string, unknown>): boolean {
  return Array.isArray(d.findings);
}

/**
 * Traduce la forma v1 a hallazgos, campo a campo.
 *
 * La severidad la asigna esta funcion porque v1 no la trae: un endpoint
 * especificado y no implementado es trabajo que falta (`high`), un desajuste
 * entre contrato y codigo es una mentira publicada (`high`), una ruta que nadie
 * especifico es deuda (`medium`) y un escenario sin prueba es cobertura que
 * falta (`medium`). Va documentado aqui y no inventado en cada punto de uso.
 */
function normalizarV1(d: GapAnalysisV1): AnalisisNormalizado {
  const endpoints = d.endpoints ?? {};
  const findings: GapFinding[] = [];

  for (const e of endpoints.missing ?? []) {
    findings.push({
      id: e.id ?? `MISSING-${(e.method ?? "ANY").toUpperCase()}-${e.path ?? "?"}`,
      category: "missing",
      severity: "high",
      artifact: e.specFile,
      description: `${e.method ?? "?"} ${e.path ?? "?"} esta especificado pero no implementado`,
      source: e.specFile,
    });
  }

  for (const e of endpoints.orphan ?? []) {
    findings.push({
      id: idDeHuerfano(e),
      category: "orphan",
      severity: "medium",
      artifact: e.codeFile,
      description: `${e.method ?? "?"} ${e.path ?? "?"} esta implementado en ${
        e.handler ?? "codigo"
      } pero no lo especifica ningun contrato`,
      target: e.codeFile,
    });
  }

  for (const e of endpoints.mismatch ?? []) {
    findings.push({
      id: e.id ?? `MISMATCH-${e.specFile ?? "?"}`,
      category: "mismatch",
      severity: "high",
      artifact: e.specFile,
      description: e.issue ?? "El contrato y el codigo difieren",
      source: e.specFile,
      target: e.codeFile,
    });
  }

  /*
   * Los escenarios BDD sin fichero de prueba NO son endpoints.
   *
   * Comparten la categoria `missing` porque las dos cosas faltan, y separarlos en
   * una categoria nueva romperia el filtro que ya usa el resto del sistema. Pero
   * la descripcion lo dice, no traen `artifact` de contrato, y el desglose de mas
   * abajo publica cuantos son de cada tipo: sin eso, "faltan 3 missing" mezclaria
   * rutas sin implementar con pruebas sin escribir y seria enganoso en las dos
   * direcciones.
   */
  const escenariosBdd = d.bddCoverage?.missing ?? [];
  for (const id of escenariosBdd) {
    findings.push({
      id,
      category: "missing",
      severity: "medium",
      description: `Escenario BDD ${id} sin fichero de prueba que lo implemente (no es un endpoint)`,
    });
  }

  const cuenta = (c: GapFinding["category"]) =>
    findings.filter((f) => f.category === c).length;

  return {
    generatedAt: d.generatedAt,
    projectName: null,
    projectFramework: d.projectFramework ?? null,
    summary: {
      total: findings.length,
      missing: cuenta("missing"),
      orphan: cuenta("orphan"),
      mismatch: cuenta("mismatch"),
    },
    findings,
    desglose: {
      endpoints: (endpoints.missing ?? []).length,
      escenariosBdd: escenariosBdd.length,
    },
    estadisticasOrigen: d.statistics ?? null,
  };
}

function normalizarCanonica(d: GapAnalysis): AnalisisNormalizado {
  return {
    generatedAt: d.generatedAt,
    projectName: d.projectName ?? null,
    projectFramework: null,
    summary: d.summary,
    findings: d.findings,
    desglose: {
      endpoints: d.findings.filter((f) => f.category === "missing").length,
      escenariosBdd: 0,
    },
    estadisticasOrigen: null,
  };
}

// ---------------------------------------------------------------------------
// Execution
// ---------------------------------------------------------------------------

/**
 * @param cwd Directorio desde el que buscar `.sdd/gap-analysis.json`. Es un
 *   parametro de la funcion y NO del esquema de entrada de la herramienta: un
 *   cliente MCP no debe poder apuntar la lectura a donde quiera. Existe para que
 *   las pruebas sean hermeticas sin `process.chdir`, que es global al proceso y
 *   convierte cualquier suite en paralelo en una carrera.
 */
export function executeGaps(args: GapsArgs, cwd?: string): string {
  const { category = "all", format = "summary" } = args;

  const crudo = loadGapAnalysis(cwd);
  if (!crudo) {
    return JSON.stringify({
      error: true,
      message:
        "No gap analysis found. Run /sdd-gap-detector first.",
    });
  }

  let data: AnalisisNormalizado;
  if (esFormaCanonica(crudo)) {
    data = normalizarCanonica(crudo as unknown as GapAnalysis);
  } else if (esFormaV1(crudo)) {
    data = normalizarV1(crudo as unknown as GapAnalysisV1);
  } else {
    /*
     * Una tercera forma. El mensaje NOMBRA las claves encontradas en vez de
     * decir "no se pudo leer": sin eso hay que abrir el fichero a mano para
     * averiguar por que, y quien lo lee es un modelo que no puede.
     */
    const claves = Object.keys(crudo);
    return JSON.stringify({
      error: true,
      message:
        `El fichero .sdd/gap-analysis.json no tiene ninguna de las dos formas conocidas. ` +
        `Se esperaba un array "findings" (forma canonica) o un objeto "endpoints"/"bddCoverage" ` +
        `(sdd-gap-analysis-v1). Claves encontradas: ${claves.join(", ") || "(ninguna)"}.`,
      clavesEncontradas: claves,
      formasSoportadas: ["findings[]", "sdd-gap-analysis-v1"],
    });
  }

  // Filter findings by category
  const findings =
    category === "all"
      ? data.findings
      : data.findings.filter((f) => f.category === category);

  if (format === "detail") {
    const output = {
      generatedAt: data.generatedAt,
      projectName: data.projectName,
      projectFramework: data.projectFramework,
      filter: category,
      totalFindings: findings.length,
      summary: data.summary,
      desglose: data.desglose,
      estadisticasOrigen: data.estadisticasOrigen,
      findings: findings.map((f) => ({
        id: f.id,
        category: f.category,
        severity: f.severity,
        artifact: f.artifact ?? null,
        description: f.description,
        recommendation: f.recommendation ?? null,
        source: f.source ?? null,
        target: f.target ?? null,
      })),
    };

    return JSON.stringify(output) + getNextStepHint("sdd_gaps", args);
  }

  // Summary mode: stats table + top issues (up to 10)
  const bySeverity: Record<string, number> = {};
  for (const f of findings) {
    bySeverity[f.severity] = (bySeverity[f.severity] ?? 0) + 1;
  }

  // Top issues: highest severity first, then alphabetical
  const severityOrder: Record<string, number> = {
    critical: 0,
    high: 1,
    medium: 2,
    low: 3,
    info: 4,
  };
  const sorted = [...findings].sort((a, b) => {
    const sa = severityOrder[a.severity.toLowerCase()] ?? 5;
    const sb = severityOrder[b.severity.toLowerCase()] ?? 5;
    return sa - sb;
  });

  const output = {
    generatedAt: data.generatedAt,
    projectName: data.projectName,
    projectFramework: data.projectFramework,
    filter: category,
    // Cuantos de los `missing` son rutas sin implementar y cuantos escenarios BDD
    // sin prueba. Sin este desglose las dos cosas se suman y el total enganna.
    desglose: data.desglose,
    // Lo que escribio el generador, sin reinterpretar.
    estadisticasOrigen: data.estadisticasOrigen,
    stats: {
      total: data.summary.total,
      missing: data.summary.missing,
      orphan: data.summary.orphan,
      mismatch: data.summary.mismatch,
      filtered: findings.length,
    },
    bySeverity,
    topIssues: sorted.slice(0, 10).map((f) => ({
      id: f.id,
      category: f.category,
      severity: f.severity,
      description: f.description,
    })),
  };

  return JSON.stringify(output) + getNextStepHint("sdd_gaps", args);
}
