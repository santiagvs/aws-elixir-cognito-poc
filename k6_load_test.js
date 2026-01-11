import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { check, group, sleep } from "k6";
import http from "k6/http";
import { Counter, Rate, Trend } from "k6/metrics";

const ELIXIR_BASE = "http://localhost:4000";
const PYTHON_BASE = "http://localhost:8000";

const elixirLoginDuration = new Trend("elixir_login_duration");
const pythonLoginDuration = new Trend("python_login_duration");
const elixirErrorRate = new Rate("elixir_error_rate");
const pythonErrorRate = new Rate("python_error_rate");
const totalRequests = new Counter("total_requests");

const elixirSuccessCounter = new Counter("elixir_success");
const elixirErrorCounter = new Counter("elixir_error");
const pythonSuccessCounter = new Counter("python_success");
const pythonErrorCounter = new Counter("python_error");

const existingUserMetrics = new Trend("existing_user_duration");
const legacyUserMetrics = new Trend("legacy_user_duration");
const invalidUserMetrics = new Trend("invalid_user_duration");

export const options = {
	scenarios: {
		constant_load: {
			executor: "constant-vus",
			vus: 50,
			duration: "2m",
			exec: "testLogin",
			gracefulStop: "30s",
		},
		spike_test: {
			executor: "ramping-vus",
			startVUs: 10,
			stages: [
				{ duration: "30s", target: 100 },
				{ duration: "1m", target: 100 },
				{ duration: "30s", target: 10 },
			],
			gracefulRampDown: "30s",
			exec: "testLogin",
		},
	},
	thresholds: {
		elixir_login_duration: ["p(95)<500"],
		python_login_duration: ["p(95)<500"],
		elixir_error_rate: ["rate<0.05"],
		python_error_rate: ["rate<0.05"],
	},
};

const testUsers = [
	{
		username: "migrated@test.com",
		password: "MigratedPass123!",
		type: "existing",
	},
	{ username: "legacy@test.com", password: "LegacyPass123!", type: "legacy" },
	{ username: "admin@legacy.com", password: "AdminPass456!", type: "legacy" },
	{ username: "newuser@test.com", password: "NewUserPass789!", type: "legacy" },
	{ username: "invalid@test.com", password: "WrongPass!", type: "invalid" },
];

function testEndpoint(baseUrl, user, isElixir) {
	const url = `${baseUrl}/login`;
	const payload = JSON.stringify({
		username: user.username,
		password: user.password,
	});

	const params = {
		headers: { "Content-Type": "application/json" },
		timeout: "10s",
	};

	const start = Date.now();
	const res = http.post(url, payload, params);
	const duration = Date.now() - start;

	totalRequests.add(1);

	const checks = {
		"status 200 para credenciais válidas":
			user.type !== "invalid" ? res.status === 200 : true,
		"status 401 para credenciais inválidas":
			user.type === "invalid" ? res.status === 401 : true,
		"tempo de resposta razoável": duration < 3000,
	};

	const success = check(res, checks);

	if (isElixir) {
		elixirLoginDuration.add(duration);
		if (success) {
			elixirSuccessCounter.add(1);
		} else {
			elixirErrorCounter.add(1);
			elixirErrorRate.add(1);
		}
	} else {
		pythonLoginDuration.add(duration);
		if (success) {
			pythonSuccessCounter.add(1);
		} else {
			pythonErrorCounter.add(1);
			pythonErrorRate.add(1);
		}
	}

	if (user.type === "existing") {
		existingUserMetrics.add(duration);
	} else if (user.type === "legacy") {
		legacyUserMetrics.add(duration);
	} else {
		invalidUserMetrics.add(duration);
	}

	return { success, duration, status: res.status };
}

export function testLogin() {
	const user = testUsers[Math.floor(Math.random() * testUsers.length)];

	if (Math.random() > 0.5) {
		group("Teste Elixir", () => {
			testEndpoint(ELIXIR_BASE, user, true);
		});
	} else {
		group("Teste Python", () => {
			testEndpoint(PYTHON_BASE, user, false);
		});
	}

	sleep(Math.random() * 0.5);
}

export function setup() {
	console.log("🚀 Iniciando testes de carga...");
	console.log(`Elixir: ${ELIXIR_BASE}`);
	console.log(`Python: ${PYTHON_BASE}`);
	console.log(`Data/Hora: ${new Date().toISOString()}`);
}

export function teardown() {
	console.log("📊 Testes concluídos!");
}

export function handleSummary(data) {
	const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
	const resultsDir = "test_results";

	const elixirStats = calculateStats(data.metrics.elixir_login_duration);
	const pythonStats = calculateStats(data.metrics.python_login_duration);

	const elixirSuccess = data.metrics.elixir_success?.values.count || 0;
	const elixirError = data.metrics.elixir_error?.values.count || 0;
	const pythonSuccess = data.metrics.python_success?.values.count || 0;
	const pythonError = data.metrics.python_error?.values.count || 0;

	const customReport = {
		test_info: {
			timestamp: new Date().toISOString(),
			duration: data.state.testRunDurationMs / 1000,
			scenarios: Object.keys(options.scenarios),
		},
		elixir: {
			total_requests: elixirSuccess + elixirError,
			successful_requests: elixirSuccess,
			failed_requests: elixirError,
			success_rate:
				((elixirSuccess / (elixirSuccess + elixirError)) * 100).toFixed(2) +
				"%",
			error_rate: data.metrics.elixir_error_rate?.values.rate
				? `${(data.metrics.elixir_error_rate.values.rate * 100).toFixed(2)}%`
				: "0%",
			response_times: elixirStats,
			thresholds: {
				p95_under_500ms: elixirStats.p95 < 500 ? "✅ PASS" : "❌ FAIL",
				error_rate_under_5:
					data.metrics.elixir_error_rate?.values.rate < 0.05
						? "✅ PASS"
						: "❌ FAIL",
			},
		},
		python: {
			total_requests: pythonSuccess + pythonError,
			successful_requests: pythonSuccess,
			failed_requests: pythonError,
			success_rate:
				((pythonSuccess / (pythonSuccess + pythonError)) * 100).toFixed(2) +
				"%",
			error_rate: data.metrics.python_error_rate?.values.rate
				? `${(data.metrics.python_error_rate.values.rate * 100).toFixed(2)}%`
				: "0%",
			response_times: pythonStats,
			thresholds: {
				p95_under_500ms: pythonStats.p95 < 500 ? "✅ PASS" : "❌ FAIL",
				error_rate_under_5:
					data.metrics.python_error_rate?.values.rate < 0.05
						? "✅ PASS"
						: "❌ FAIL",
			},
		},
		comparison: {
			winner_avg_response:
				elixirStats.avg < pythonStats.avg ? "Elixir" : "Python",
			winner_p95_response:
				elixirStats.p95 < pythonStats.p95 ? "Elixir" : "Python",
			winner_success_rate:
				elixirSuccess / (elixirSuccess + elixirError) >
				pythonSuccess / (pythonSuccess + pythonError)
					? "Elixir"
					: "Python",
		},
		user_type_metrics: {
			existing_users: calculateStats(data.metrics.existing_user_duration),
			legacy_users: calculateStats(data.metrics.legacy_user_duration),
			invalid_users: calculateStats(data.metrics.invalid_user_duration),
		},
	};

	const markdownReport = generateMarkdownReport(customReport);

	return {
		[`${resultsDir}/summary_${timestamp}.json`]: JSON.stringify(
			customReport,
			null,
			2,
		),
		[`${resultsDir}/summary_${timestamp}.md`]: markdownReport,
		[`${resultsDir}/summary_${timestamp}.html`]: htmlReport(data),
		stdout: textSummary(data, { indent: " ", enableColors: true }),
	};
}

function calculateStats(metric) {
	if (!metric || !metric.values) {
		return {
			avg: 0,
			min: 0,
			max: 0,
			p50: 0,
			p90: 0,
			p95: 0,
			p99: 0,
		};
	}

	return {
		avg: metric.values.avg?.toFixed(2) || 0,
		min: metric.values.min?.toFixed(2) || 0,
		max: metric.values.max?.toFixed(2) || 0,
		p50: metric.values.med?.toFixed(2) || 0,
		p90: metric.values["p(90)"]?.toFixed(2) || 0,
		p95: metric.values["p(95)"]?.toFixed(2) || 0,
		p99: metric.values["p(99)"]?.toFixed(2) || 0,
	};
}

function generateMarkdownReport(report) {
	return `# 📊 Relatório de Testes de Carga - Cognito PoC

**Data/Hora:** ${report.test_info.timestamp}  
**Duração:** ${report.test_info.duration.toFixed(2)}s  
**Cenários:** ${report.test_info.scenarios.join(", ")}

---

## 🚀 Elixir Performance

| Métrica | Valor |
|---------|-------|
| **Total de Requisições** | ${report.elixir.total_requests} |
| **Requisições Bem-Sucedidas** | ${report.elixir.successful_requests} |
| **Requisições Falhadas** | ${report.elixir.failed_requests} |
| **Taxa de Sucesso** | ${report.elixir.success_rate} |
| **Taxa de Erro** | ${report.elixir.error_rate} |

### ⏱️ Tempos de Resposta (ms)

| Percentil | Valor |
|-----------|-------|
| Médio | ${report.elixir.response_times.avg} |
| Mínimo | ${report.elixir.response_times.min} |
| Máximo | ${report.elixir.response_times.max} |
| P50 (Mediana) | ${report.elixir.response_times.p50} |
| P90 | ${report.elixir.response_times.p90} |
| P95 | ${report.elixir.response_times.p95} |
| P99 | ${report.elixir.response_times.p99} |

### ✅ Thresholds

- P95 < 500ms: **${report.elixir.thresholds.p95_under_500ms}**
- Taxa de Erro < 5%: **${report.elixir.thresholds.error_rate_under_5}**

---

## 🐍 Python Performance

| Métrica | Valor |
|---------|-------|
| **Total de Requisições** | ${report.python.total_requests} |
| **Requisições Bem-Sucedidas** | ${report.python.successful_requests} |
| **Requisições Falhadas** | ${report.python.failed_requests} |
| **Taxa de Sucesso** | ${report.python.success_rate} |
| **Taxa de Erro** | ${report.python.error_rate} |

### ⏱️ Tempos de Resposta (ms)

| Percentil | Valor |
|-----------|-------|
| Médio | ${report.python.response_times.avg} |
| Mínimo | ${report.python.response_times.min} |
| Máximo | ${report.python.response_times.max} |
| P50 (Mediana) | ${report.python.response_times.p50} |
| P90 | ${report.python.response_times.p90} |
| P95 | ${report.python.response_times.p95} |
| P99 | ${report.python.response_times.p99} |

### ✅ Thresholds

- P95 < 500ms: **${report.python.thresholds.p95_under_500ms}**
- Taxa de Erro < 5%: **${report.python.thresholds.error_rate_under_5}**

---

## 🏆 Comparação

| Critério | Vencedor |
|----------|----------|
| Tempo Médio de Resposta | **${report.comparison.winner_avg_response}** |
| Tempo P95 de Resposta | **${report.comparison.winner_p95_response}** |
| Taxa de Sucesso | **${report.comparison.winner_success_rate}** |

---

## 👥 Métricas por Tipo de Usuário

### Usuários Existentes (já migrados)
- Tempo Médio: ${report.user_type_metrics.existing_users.avg}ms
- P95: ${report.user_type_metrics.existing_users.p95}ms

### Usuários Legados (primeira autenticação)
- Tempo Médio: ${report.user_type_metrics.legacy_users.avg}ms
- P95: ${report.user_type_metrics.legacy_users.p95}ms

### Credenciais Inválidas
- Tempo Médio: ${report.user_type_metrics.invalid_users.avg}ms
- P95: ${report.user_type_metrics.invalid_users.p95}ms

---

*Relatório gerado automaticamente pelo K6*
`;
}
