#!/bin/bash
STACK_NAME="nocode"
COMPOSE_FILE="docker-stack.yml"

IMAGES=(
  "nginx:alpine"
  "openanalytics/shinyproxy:latest"
  "scygu/no-code-app:latest"
  "scygu/no-code-pycaret:latest"
)

echo "================================================"
echo " Pulling latest images"
echo "================================================"

UPDATED_IMAGES=()

for IMAGE in "${IMAGES[@]}"; do
  echo "  ⏳ Pulling $IMAGE..."
  PULL_OUTPUT=$(docker pull $IMAGE 2>&1)
  if [ $? -ne 0 ]; then
    echo "  ✗ Failed to pull $IMAGE"
    exit 1
  fi

  if echo "$PULL_OUTPUT" | grep -q "Status: Downloaded newer image"; then
    echo "  🔄 $IMAGE — new version downloaded"
    UPDATED_IMAGES+=("$IMAGE")
  elif echo "$PULL_OUTPUT" | grep -q "Status: Image is up to date"; then
    echo "  ✓ $IMAGE — already up to date"
  else
    echo "  ✓ $IMAGE — pulled"
    UPDATED_IMAGES+=("$IMAGE")
  fi
done

echo ""
echo "================================================"
echo " Deploying / Updating stack: $STACK_NAME"
echo " (Volumes will NOT be removed)"
echo "================================================"

docker stack deploy \
  -c $COMPOSE_FILE \
  $STACK_NAME \
  --with-registry-auth \
  --resolve-image always

if [ $? -ne 0 ]; then
  echo "  ✗ Stack deploy failed."
  exit 1
fi

if [ ${#UPDATED_IMAGES[@]} -gt 0 ]; then
  echo ""
  echo "================================================"
  echo " Rolling update for services using updated images"
  echo "================================================"

  SERVICES=$(docker stack services $STACK_NAME --format "{{.Name}} {{.Image}}")

  while IFS= read -r LINE; do
    SVC_NAME=$(echo "$LINE" | awk '{print $1}')
    SVC_IMAGE=$(echo "$LINE" | awk '{print $2}' | cut -d'@' -f1)  # strip digest if present

    for UPDATED in "${UPDATED_IMAGES[@]}"; do
      if [[ "$SVC_IMAGE" == "$UPDATED" ]]; then
        echo "  🔄 Forcing rolling update for: $SVC_NAME"
        docker service update --force --image "$UPDATED" "$SVC_NAME"
        break
      fi
    done
  done <<< "$SERVICES"
fi

echo ""
echo "Waiting for all services to be ready..."
echo ""

while true; do
  SERVICES=$(docker stack services $STACK_NAME --format "{{.Name}}")
  ALL_READY=true
  ANY_FAILED=false

  for SERVICE in $SERVICES; do
    REPLICAS=$(docker service ls --filter "name=${SERVICE}" --format "{{.Replicas}}")
    DESIRED=$(echo $REPLICAS | cut -d'/' -f2 | awk '{print $1}')
    CURRENT=$(echo $REPLICAS | cut -d'/' -f1 | awk '{print $1}')

    if [ "$DESIRED" = "0" ]; then
      echo "  ✓ $SERVICE (managed by ShinyProxy, skipped)"
      continue
    fi

    # Check for failed tasks on regular services
    FAILED=$(docker service ps $SERVICE \
      --filter "desired-state=shutdown" \
      --format "{{.Error}}" 2>/dev/null | grep -v "^$" | head -1)

    if [ -n "$FAILED" ]; then
      ANY_FAILED=true
      echo "  ✗ $SERVICE FAILED: $FAILED"
      continue
    fi

    if [ "$CURRENT" != "$DESIRED" ]; then
      ALL_READY=false
      echo "  ⏳ $SERVICE ($REPLICAS replicas ready) - updating..."
    else
      echo "  ✓ $SERVICE ($REPLICAS replicas ready)"
    fi
  done

  if $ANY_FAILED; then
    echo ""
    echo "ERROR: One or more services failed. Check logs with:"
    echo "  docker service logs ${STACK_NAME}_<service_name>"
    exit 1
  fi

  if $ALL_READY; then
    echo ""
    echo "================================================"
    echo " All services are up and running!"
    echo " Access the app at: http://$(hostname -I | awk '{print $1}'):8088"
    echo "================================================"
    break
  fi

  echo ""
  sleep 5
  echo "Rechecking..."
  echo ""
done
