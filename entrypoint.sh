#!/bin/bash

set -ex

# ----------------------------- [START] main logic --------------------------- #

# allow mounting a custom entrypoint script at /usr/bin/custom_entrypoint
if [ -f "/usr/bin/custom_entrypoint" ]; then
  chmod a+x "/usr/bin/custom_entrypoint" && \
  "/usr/bin/custom_entrypoint" "$@"
else
  # injected by kubernetes
  cacert="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"

  if [ ! "$WAIT_FOR_IT" = "true" ]
  then
    echo "Not waiting on any pods."
    echo "Exiting without error..."
    exit 0
  fi


  # # accept string of semicolon separated "node-pool-name=3" strings
  # # each string has a comma separated number of nodes to wait for
  # IFS=';' read -ra K8S_NODES <<< "$WAIT_FOR_NODES"
  # for k8s_node_pool in "${K8S_NODES[@]}"; do
  #   IFS='=' read -ra NODE_POOL_NAME_AND_COUNT <<< "$k8s_node_pool"
  #
  #   node_pool_name=${NODE_POOL_NAME_AND_COUNT[0]}
  #   num_nodes_desired=${NODE_POOL_NAME_AND_COUNT[1]}
  #
  #   num_nodes_running=$(kubectl get nodes -o json | jq "[.items[].metadata.labels | select(.\"cloud.google.com/gke-nodepool\" == \"$node_pool_name\")] | length")
  #
  #   polling_wait_seconds=5
  #   while [ "$num_nodes_running" -lt "$num_nodes_desired" ]
  #   do
  #     # Will update the same line in the shell until it finishes
  #     echo -e "\r[notice] $second_counter seconds have passed waiting on nodes to become available..."
  #
  #     sleep $polling_wait_seconds
  #
  #     num_nodes_running=$(kubectl get nodes -o json | jq "[.items[].metadata.labels | select(.\"cloud.google.com/gke-nodepool\" == \"$node_pool_name\")] | length")
  #   done
  # done

  # accept string of semicolon separated "<service-name>.<namespace>" strings
  IFS=';' read -ra KUBERNETES_SERVICES_EXTERNAL_IPS <<< "$WAIT_FOR_EXTERNAL_IPS"
  for service in "${KUBERNETES_SERVICES_EXTERNAL_IPS[@]}"; do
    IFS='.' read -ra SERVICE_NAMESPACE <<< "$service"

    service=${SERVICE_NAMESPACE[0]}
    namespace=${SERVICE_NAMESPACE[1]}

    service_created=$(curl -s --cacert $cacert --header "Authorization: Bearer $token" https://kubernetes.default.svc/api/v1/namespaces/$namespace/endpoints/$service)

    service_status="$(echo $service_created | jq -r '.status')"

    # + service_status=Failure
    # + echo 'Service status: '\''Failure'\'''
    # Service status: 'Failure'
    echo "Service status: '$service_status'"

    if [ "$service_status" = "Failure" ]
    then
      # + echo NotFound
      # NotFound
      echo "Service was not found. Reasoning:"
      echo "$(echo $service_created | jq -r '.reason')"

    else
      service_available=$(curl -s --cacert $cacert --header "Authorization: Bearer $token" "https://kubernetes.default.svc/api/v1/namespaces/$namespace/services/$service/?exact")

      ips_available=$(echo "$service_available" | jq -r '.status.loadBalancer.ingress | length')

      second_counter=0
      polling_wait_seconds=5
      while [ -z "$ips_available" ] || [ $ips_available -lt 1 ]
      do
        # Will update the same line in the shell until it finishes
        echo -e "\r[notice] $second_counter seconds have passed waiting on IPs to become available..."

        sleep $polling_wait_seconds

        service_available=$(curl -s --cacert $cacert --header "Authorization: Bearer $token" "https://kubernetes.default.svc/api/v1/namespaces/$namespace/services/$service/?exact")

        ips_available=$(echo "$service_available" | jq -r '.status.loadBalancer.ingress | length')
      done

      service_ip=$(echo "$service_available" | jq '.status.loadBalancer.ingress[0].ip')

      if [ -z "$service_ip" ]
      then
        echo "[warning] service_ip is an empty string instead of an IP address."
        echo "[warning] kubernetes.default.svc may not have been resolved."

      else
        echo "Service external IP address found: $service_ip"
      fi

      echo "Service found ($service): $service_ip"
    fi
  done


  # accept string of semicolon separated "domain-name=ip-address" strings
  IFS=';' read -ra DNS_MATCHES <<< "$WAIT_FOR_DNS_MATCHES"
  for dns_match in "${DNS_MATCHES[@]}"; do
    IFS='=' read -ra DOMAIN_AND_IP <<< "$dns_match"

    # was bugging out on malformatted DNS names like drone\\.grinsides\\.com
    domain_name="$(echo ${DOMAIN_AND_IP[0]} | sed 's/\\//g')"
    ip_address=${DOMAIN_AND_IP[1]}

    # match DNS with an external IP before continuing
    # bash-4.4# nslookup grinsides.com
    # nslookup: can't resolve '(null)': Name does not resolve
    #
    # Name:      grinsides.com
    # Address 1: 35.237.17.14 14.17.237.35.bc.googleusercontent.com
    ip_resolved=$(nslookup "$domain_name" 2>/dev/null | grep "Address" | awk '{ print $3 }')

    second_counter=0
    polling_wait_seconds=5
    while [ -z "$ip_resolved" ] || [ "$ip_resolved" != "$ip_address" ]
    do
      # Will update the same line in the shell until it finishes
      echo -e "\r[notice] $second_counter seconds have passed waiting on $domain_name to resolve to $ip_address... currently: '$ip_resolved'"

      sleep $polling_wait_seconds

      ip_resolved=$(nslookup "$domain_name" 2>/dev/null | grep "Address" | awk '{ print $3 }')
    done
  done

  # accept string of semicolon separated "<service-name>.<namespace>" strings
  IFS=';' read -ra KUBERNETES_SERVICES <<< "$WAIT_FOR_PODS"
  for service in "${KUBERNETES_SERVICES[@]}"; do
    IFS='.' read -ra SERVICE_NAMESPACE <<< "$service"

    service=${SERVICE_NAMESPACE[0]}
    namespace=${SERVICE_NAMESPACE[1]}

    pods_available=$(curl -s --cacert $cacert --header "Authorization: Bearer $token" https://kubernetes.default.svc/api/v1/namespaces/$namespace/endpoints/$service | jq -r '.subsets[].addresses | length')

    if [ -z "$pods_available" ]
    then
      echo "[warning] pods_available is an empty string instead of an integer."
      echo "[warning] kubernetes.default.svc may not have been resolved."
    fi

    second_counter=0
    polling_wait_seconds=5
    while [ -z "$pods_available" ] || [ $pods_available -lt 1 ]
    do
      # Will update the same line in the shell until it finishes
      echo -e "\r[notice] $second_counter seconds have passed..."

      sleep $polling_wait_seconds

      pods_available=$(curl -s --cacert $cacert --header "Authorization: Bearer $token" https://kubernetes.default.svc/api/v1/namespaces/$namespace/endpoints/$service | jq -r '.subsets[].addresses | length')
    done
  done

  echo "[success] All services depended on are running."
fi
# ------------------------------ [END] main logic ---------------------------- #

set +ex
