# gitops-lab

Declarative delivery for a single-node Kubernetes cluster. Cluster state is defined entirely in this
repository; ArgoCD reconciles the cluster against `main`. `kubectl apply` is not part of the normal
workflow.

**k3s** provides the cluster, **Kustomize** composes the manifests, **ArgoCD** delivers them, and
**Traefik** handles ingress. The workload itself (`traefik/whoami`) is a placeholder — the subject
here is the delivery mechanism, not the application.

## Architecture

```
Git (this repo)
      |
      |  ArgoCD polls main
      v
  root Application  ->  Application objects in namespace argocd
                              |
                              +-- whoami-dev    -> namespace whoami-dev
                              +-- whoami-prod   -> namespace whoami-prod
                              +-- infra-argocd  -> ArgoCD ingress
```

Two reconciliation loops run independently. `root` compares `infra/argocd/applications/` against the
Application objects in the cluster; each child Application compares its own source path against the
workloads it owns. Neither depends on the other, so a root in `OutOfSync` does not block child
applications from syncing.

```
apps/whoami/base/         deployment, service, ingress, serviceaccount
apps/whoami/overlays/     namespace, replica count, hostname per environment
infra/namespaces/
infra/argocd/root.yaml    bootstrap Application, applied manually
infra/argocd/applications/  one Application per deployed component
```

`apps/` and `infra/` are separated by ownership boundary: application workloads against platform
components. The split maps directly onto CODEOWNERS in a multi-team setup.

## Design decisions

**`base/` holds no environment-specific values.** Hostnames, replica counts and namespaces are set
in overlays. The base ingress carries a non-resolving placeholder host, so deploying `base/` alone
fails visibly rather than serving under an unintended domain.

**Selectors contain only `app.kubernetes.io/name`.** `spec.selector` on a Deployment is immutable
after creation; including a value that varies by environment makes the Deployment unmodifiable.
Environment labels are applied with `includeSelectors: false` so Kustomize does not write them into
the selector.

**`root.yaml` is excluded from every kustomization.** Placing it under ArgoCD management would allow
a single commit to remove ArgoCD's ability to recover. It is applied manually, once. The tradeoff is
that changes to `root.yaml` require a manual re-apply and are not picked up from Git.

**Applications carry `resources-finalizer.argocd.argoproj.io`.** Without the finalizer, deleting an
Application removes the object but leaves its managed resources running unowned.

## Bootstrap

Against a running k3s cluster: install ArgoCD with `--server-side` (client-side apply stores the
manifest in an annotation and the ApplicationSet CRD exceeds the 262144-byte limit), set
`server.insecure=true` in `argocd-cmd-params-cm` so ArgoCD and Traefik do not both terminate TLS,
register this repository with a read-only deploy key, then:

```bash
kubectl apply -f infra/argocd/root.yaml
```

Everything after that is driven from Git.

## Validation

The API server prunes fields absent from a CRD's schema without reporting an error. A misspelled key
under `syncPolicy` produces an Application that is created successfully and never syncs, with no
diagnostic beyond a persistent `OutOfSync` on the parent.

```bash
kubeconform -strict -summary -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  infra/argocd/applications/*.yaml infra/argocd/root.yaml
```

## Limitations

Single node: `topologySpreadConstraints` and PodDisruptionBudgets are present for correctness but
have no effect. Storage is `local-path` rather than a CSI driver. TLS is not configured, as
Let's Encrypt HTTP-01 requires public reachability. Secrets management is not yet in place; Sealed
Secrets or SOPS is a prerequisite before any sensitive value belongs in this repository.
