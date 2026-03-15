const browserAPI = globalThis.browser ?? globalThis.chrome;

const loadingView = document.getElementById("loading");
const resultView = document.getElementById("result");
const errorView = document.getElementById("error");
const retryButton = document.getElementById("retry-button");
const openDetailsButton = document.getElementById("open-details-button");
const resultBadge = document.getElementById("result-badge");
const resultHost = document.getElementById("result-host");
const resultURL = document.getElementById("result-url");
const resultProtocol = document.getElementById("result-protocol");
const resultCommonName = document.getElementById("result-common-name");
const resultTrust = document.getElementById("result-trust");
const resultHeadline = document.getElementById("result-headline");
const resultIssuer = document.getElementById("result-issuer");
const resultValidity = document.getElementById("result-validity");
const resultChain = document.getElementById("result-chain");
const findingView = document.getElementById("finding");
const resultFindingTitle = document.getElementById("result-finding-title");
const resultFindingMessage = document.getElementById("result-finding-message");
const errorMessage = document.getElementById("error-message");

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
  resultBadge.textContent = response.trustBadge;
  resultBadge.className = `badge badge-${response.tone}`;
  resultHost.textContent = response.host;
  resultURL.textContent = response.url;
  resultProtocol.textContent = response.protocolName;
  resultCommonName.textContent = response.commonName;
  resultTrust.textContent = response.trustSummary;
  resultHeadline.textContent = response.securityHeadline;
  resultIssuer.textContent = `Issuer: ${response.issuerSummary}`;
  resultValidity.textContent = `${response.validityStatus} through ${response.validUntil}`;
  currentReportToken = response.reportToken ?? "";

  resultChain.replaceChildren();
  for (const name of response.chainNames ?? []) {
    const item = document.createElement("li");
    item.textContent = name;
    resultChain.appendChild(item);
  }

  const title = response.topFindingTitle?.trim();
  const message = response.topFindingMessage?.trim();

  if (title && message) {
    resultFindingTitle.textContent = title;
    resultFindingMessage.textContent = message;
    findingView.classList.remove("hidden");
  } else {
    findingView.classList.add("hidden");
  }

  resultView.classList.remove("hidden");
  errorView.classList.add("hidden");
  openDetailsButton.classList.toggle("hidden", !currentReportToken);
}

function renderError(message) {
  errorMessage.textContent = message;
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
