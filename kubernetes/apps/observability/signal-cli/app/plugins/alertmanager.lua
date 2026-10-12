-- Receives a native Alertmanager webhook and forwards it to a Signal group.
-- Alertmanager calls /v1/plugins/alertmanager/<number>/<group-id>, where
-- <number> is the linked sender account and <group-id> the "group.xxx" id.
--
-- TODO: obsolete once Alertmanager >= v0.35 is deployed. Its webhook `payload`
-- decodes toJson output as plain strings (prometheus/alertmanager#5098), so
-- /v2/send can be called directly and this plugin removed. Up to v0.34 the
-- rendered values get YAML-parsed, breaking the number and message text.
local http = require("http")
local json = require("json")

local function respond(status, body)
	pluginOutputData:SetHttpStatusCode(status)
	pluginOutputData:SetPayload(json.encode(body))
end

local function format(payload)
	local alerts = payload.alerts or {}
	local labels = payload.commonLabels or {}
	local status = payload.status or "unknown"

	local firing = 0
	for _, alert in ipairs(alerts) do
		if alert.status == "firing" then
			firing = firing + 1
		end
	end

	local header
	if status == "firing" then
		header = string.format("🔥 FIRING (%d): %s", firing, labels.alertname or "alert")
	else
		header = string.format("✅ RESOLVED: %s", labels.alertname or "alert")
	end

	local lines = { header }
	for _, alert in ipairs(alerts) do
		local a = alert.annotations or {}
		local l = alert.labels or {}
		local text = a.summary or a.description or a.message or l.alertname or ""
		local scope = l.namespace and (" [" .. l.namespace .. "]") or ""
		local severity = l.severity and (l.severity .. ": ") or ""
		table.insert(lines, "• " .. severity .. text .. scope)
	end

	if payload.externalURL then
		table.insert(lines, payload.externalURL)
	end
	return table.concat(lines, "\n")
end

function exec()
	local ok, payload = pcall(json.decode, pluginInputData.payload)
	if not ok or type(payload) ~= "table" then
		respond(400, { error = "invalid alertmanager payload" })
		return
	end

	local response, err = http.request("POST", "http://127.0.0.1:8080/v2/send", {
		timeout = "30s",
		headers = { ["Content-Type"] = "application/json" },
		body = json.encode({
			number = pluginInputData.Params.number,
			recipients = { pluginInputData.Params.group },
			message = format(payload),
			notify_self = true,
		}),
	})

	if response == nil then
		respond(502, { error = "signal send failed: " .. tostring(err) })
		return
	end
	pluginOutputData:SetHttpStatusCode(response.status_code)
	pluginOutputData:SetPayload(response.body)
end
