local request_uri = ngx.var.request_uri

-- if we are trying to read the metrics, don't overwrite the auth
if request_uri ~= "/metrics" then
    ngx.req.set_header("Authorization", ngx.var.http_proxy_authorization)
end