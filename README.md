# Wait for It Init Container

This container's job is to stall a deployment from running any containers until some network conditions are met.

## Config environment variables

This image checks for and matches the conditions listed below (in order) before allowing the other containers in the deployment to run.

1 `WAIT_FOR_IT`
  * form: `"true"` or `"false"`
  * must equal `"true"` or the init container will be ignored
  * examples:

    ```sh
    WAIT_FOR_IT="true"
    ```

    ```sh
    WAIT_FOR_IT="false"
    ```

2 `WAIT_FOR_PODS`
  * Waits for other service's pods to be running before containers can start
  * form: `<service-name>.<namespace>;<service-name-2>.<namespace-2>`
  * examples:

    ```sh
    WAIT_FOR_PODS="mysql.test"
    ```

    ```sh
    WAIT_FOR_PODS="mysql.test;kube-dns.kube-system"
    ```

3. `WAIT_FOR_EXTERNAL_IPS`
  * Waits for a k8s service to have an exposed external IP (not `<pending>` or `ClusterIP`)
  * form: `<service-name>.<namespace>;<service-name-2>.<namespace-2>`
  * examples:

    ```sh
    WAIT_FOR_EXTERNAL_IPS="nginx.test"
    ```

    ```sh
    WAIT_FOR_EXTERNAL_IPS="nginx.test;otherservice.default"
    ```

4. `WAIT_FOR_DNS_MATCHES`
  * Waits for a domain name to match a specific IP before continuing
  * form: `<domain-name>=<ip-address>;<domain-name-2>=<ip-address-2>`
  * examples:

    ```sh
    WAIT_FOR_DNS_MATCHES="drone.grinsides.com=35.237.17.14;grinsides.com=35.237.17.15"
    ```

# Handle Kubernetes Services Dependencies

If you need to make sure a database is running before starting a GUI pod, this is the init container for you.

To wait for:
  1. `mysql` pod to start in `databases` namespace
  2. `mongo` pod to start in `othernamespace` namespace
  3. `redis` pod to start in `anothernamespace` namespace

Configure an init container in your deployment like this:

```yaml
initContainers:
- name: "wait-for-services"
  image: stevenaldinger/docker-k8s-wait-for-it
  imagePullPolicy: Always
  env:
  - name: WAIT_FOR_IT
    value: "true"
  - name: WAIT_FOR_PODS
    value: "mysql.databases;mongo.othernamespace;redis.anothernamespace"
  - name: WAIT_FOR_EXTERNAL_IPS
    value: "nginx.proxy"
  - name: WAIT_FOR_DNS_MATCHES
    value: "drone.grinsides.com=35.237.17.14;grinsides.com=35.237.17.15"
```

## While testing:

Run this to view init logs:

```sh
kubectl logs -f $(kubectl get po -l app=redis -o jsonpath='{.items[0].metadata.name}') -c redis-init
```

Run this to bash into init container:

```sh
kubectl exec -it $(kubectl get po -l app=redis -o jsonpath='{.items[0].metadata.name}') -c redis-init bash
```
