#!/bin/bash
STACK_NAME="nocode"

echo "================================================"
echo " Safely stopping stack: $STACK_NAME"
echo " (Volumes will NOT be removed)"
echo "================================================"
echo ""

# Check if stack exists
if ! docker stack ls --format "{{.Name}}" | grep -q "^${STACK_NAME}$"; then
  echo "  ℹ Stack '$STACK_NAME' is not running. Nothing to stop."
  exit 0
fi

# List services before stopping
echo "  Services to be stopped:"
docker stack services $STACK_NAME --format "    - {{.Name}} ({{.Replicas}} replicas)"
echo ""

# Stop ShinyProxy-managed containers first (not controlled by Swarm)
echo "  ⏳ Stopping ShinyProxy-spawned containers..."
SP_CONTAINERS=$(docker ps --format "{{.ID}} {{.Names}}" | grep "sp-container-" | awk '{print $1}')
if [ -n "$SP_CONTAINERS" ]; then
  echo "$SP_CONTAINERS" | xargs docker stop
  echo "  ✓ ShinyProxy containers stopped"
else
  echo "  ℹ No ShinyProxy containers running"
fi
echo ""

# Scale all services down to 0 for graceful shutdown
echo "  ⏳ Scaling all services down gracefully..."
SERVICES=$(docker stack services $STACK_NAME --format "{{.Name}}")
for SERVICE in $SERVICES; do
  docker service scale ${SERVICE}=0 --detach=true 2>/dev/null
  echo "  ✓ $SERVICE scaling down..."
done

# Wait until ALL tasks for every service are fully shut down
# (containers can linger even after replicas hit 0 — network stays busy until they're gone)
echo ""
echo "  ⏳ Waiting for all containers to fully exit before removing network..."
TIMEOUT=90
ELAPSED=0
while true; do
  RUNNING_TASKS=0
  for SERVICE in $SERVICES; do
    COUNT=$(docker service ps $SERVICE \
      --filter "desired-state=running" \
      --format "{{.ID}}" 2>/dev/null | wc -l)
    RUNNING_TASKS=$((RUNNING_TASKS + COUNT))
  done

  if [ "$RUNNING_TASKS" -eq 0 ]; then
    echo "  ✓ All containers have stopped."
    break
  fi

  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "  ⚠ Timed out waiting for containers to exit ($RUNNING_TASKS still running)."
    echo "    Proceeding anyway — you may need to manually run: docker stack rm $STACK_NAME"
    break
  fi

  echo "    $RUNNING_TASKS task(s) still shutting down... (${ELAPSED}s elapsed)"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

echo ""
echo "  ⏳ Removing stack (services & networks only)..."
docker stack rm $STACK_NAME

if [ $? -ne 0 ]; then
  echo ""
  echo "  ✗ Stack removal failed. Retrying in 10s..."
  sleep 10
  docker stack rm $STACK_NAME
  if [ $? -ne 0 ]; then
    echo "  ✗ Still failed. Try manually: docker stack rm $STACK_NAME"
    exit 1
  fi
fi

# Wait until stack is fully gone
echo ""
echo "  Waiting for stack to be fully removed..."
TIMEOUT=60
ELAPSED=0
while docker stack services $STACK_NAME 2>/dev/null | grep -q "$STACK_NAME"; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "  ⚠ Timed out. Check manually: docker stack services $STACK_NAME"
    exit 1
  fi
  sleep 3
  ELAPSED=$((ELAPSED + 3))
done

echo ""
echo "================================================"
echo " Stack '$STACK_NAME' stopped successfully."
echo ""
echo " Volumes preserved:"
docker volume ls --filter "name=${STACK_NAME}" --format "    - {{.Name}}"
echo ""
echo " To restart:  ./start-stack.sh"
echo " To remove volumes (DESTRUCTIVE): docker volume rm <volume_name>"
echo "================================================"
