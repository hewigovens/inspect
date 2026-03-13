const browserAPI = globalThis.browser ?? globalThis.chrome;

const loadingView = document.getElementById("loading");
const resultView = document.getElementById("result");
const errorView = document.getElementById("error");
const retryButton = document.getElementById("retry-button");
const openDetailsButton = document.getElementById("open-details-button");

let currentReportToken = "";

async function runInspection() {
  setLoading(true);

  try {
    const [tab] = await browserAPI.tabs.query({ active: true, currentWindow: true });
    const currentURL = tab?.url;

    if (!currentURL) {
      throw new Error("The current tab does not expose a URL.");
    }

    const response = await browserAPI.runtime.sendNativeMessage({
      type: "inspect-tab",
      url: currentURL
    });

    if (!response || response.status !== "success") {
      throw new Error(response?.message ?? "Inspect did not return a valid response.");
    }

    renderSuccess(response);
  } catch (error) {
    renderError(error instanceof Error ? error.message : String(error));
  } finally {
    setLoading(false);
  }
}

function setLoading(isLoading) {
  loadingView.classList.toggle("hidden", !isLoading);
  retryButton.disabled = isLoading;

  if (isLoading) {
    resultView.classList.add("hidden");
    errorView.classList.add("hidden");
  }
}

function renderSuccess(response) {
  const badge = document.getElementById("result-badge");
  badge.textContent = response.trustBadge;
  badge.className = `badge badge-${response.tone}`;

  document.getElementById("result-host").textContent = response.host;
  document.getElementById("result-url").textContent = response.url;
  document.getElementById("result-protocol").textContent = response.protocolName;
  document.getElementById("result-common-name").textContent = response.commonName;
  document.getElementById("result-trust").textContent = response.trustSummary;
  document.getElementById("result-headline").textContent = response.securityHeadline;
  document.getElementById("result-issuer").textContent = `Issuer: ${response.issuerSummary}`;
  document.getElementById("result-validity").textContent = `${response.validityStatus} through ${response.validUntil}`;
  currentReportToken = response.reportToken ?? "";

  const chain = document.getElementById("result-chain");
  chain.replaceChildren();
  for (const name of response.chainNames ?? []) {
    const item = document.createElement("li");
    item.textContent = name;
    chain.appendChild(item);
  }

  const finding = document.getElementById("finding");
  const title = response.topFindingTitle?.trim();
  const message = response.topFindingMessage?.trim();

  if (title && message) {
    document.getElementById("result-finding-title").textContent = title;
    document.getElementById("result-finding-message").textContent = message;
    finding.classList.remove("hidden");
  } else {
    finding.classList.add("hidden");
  }

  resultView.classList.remove("hidden");
  errorView.classList.add("hidden");
  openDetailsButton.classList.toggle("hidden", !currentReportToken);
}

function renderError(message) {
  document.getElementById("error-message").textContent = message;
  errorView.classList.remove("hidden");
  resultView.classList.add("hidden");
  openDetailsButton.classList.add("hidden");
  currentReportToken = "";
}

retryButton.addEventListener("click", runInspection);
openDetailsButton.addEventListener("click", async () => {
  if (!currentReportToken) {
    return;
  }

  try {
    const deepLink = `inspect://certificate-detail?token=${encodeURIComponent(currentReportToken)}`;
    const [tab] = await browserAPI.tabs.query({ active: true, currentWindow: true });

    if (tab?.id !== undefined) {
      await browserAPI.tabs.update(tab.id, { url: deepLink });
      window.close();
      return;
    }

    const response = await browserAPI.runtime.sendNativeMessage({
      type: "open-full-details",
      reportToken: currentReportToken
    });

    if (response?.status === "opened") {
      window.close();
      return;
    }

    throw new Error(response?.message ?? "Inspect could not open the full detail view.");
  } catch (error) {
    renderError(error instanceof Error ? error.message : String(error));
  }
});
runInspection();
