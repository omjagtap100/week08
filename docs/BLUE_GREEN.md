# Blue-Green Deployment with an Automated Test Gate (Frontend)

## Problem

`04-deploy-production.yml` used to run `kubectl set image deployment/frontend ...`
directly against the single production frontend Deployment. This is a rolling
update: old pods stop while new ones start, the new image goes live for every
user immediately, and nothing verifies the new pods on the cluster before
real traffic reaches them.

## Design

- Two Deployments, `frontend-blue` and `frontend-green`, both labelled
  `app: frontend` plus a `color: blue` / `color: green` label
  ([kubernetes/production/12-frontend.yaml](../kubernetes/production/12-frontend.yaml)).
- The live `frontend` Service (`type: LoadBalancer`) selects
  `app: frontend, color: <live>`. Patching `spec.selector.color` is the only
  thing that moves traffic - no pod is restarted.
- A second `frontend-preview` Service (`type: ClusterIP`) always selects the
  **idle** colour, so the pipeline can reach the new pods without exposing
  them publicly.
- Each pod sets `APP_COLOR` and returns it as the `X-App-Color` response
  header (via nginx's built-in `envsubst` templating, see
  [frontend/nginx.conf.template](../frontend/nginx.conf.template)), so a
  `curl -I` proves which colour actually served the response.

## Release flow (`.github/workflows/04-deploy-production.yml`)

1. Read the live colour from the `frontend` Service selector; the other
   colour is idle.
2. `kubectl set image` the idle Deployment to the new build and wait for its
   rollout - the live colour keeps serving users, untouched.
3. Patch `frontend-preview` to point at the idle colour.
4. Run a smoke test (`kubectl run ... curl --fail ...`) against
   `frontend-preview` from inside the cluster.
5. Only if step 4 passes: patch the `frontend` Service selector to the idle
   colour. If step 4 fails, the job fails here and the selector is never
   touched - production is unaffected.

## Rollback

Because the previous colour is still running (never scaled down), rollback
is a single selector patch back to it:

```bash
kubectl patch service frontend -n production --type merge \
  -p '{"spec":{"selector":{"app":"frontend","color":"blue"}}}'
```
