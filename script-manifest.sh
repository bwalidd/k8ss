#!/bin/bash

# Complete Face Recognition System Deployment
# 4-GPU Django Backend + All Supporting Services

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================================${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${PURPLE}ℹ️  $1${NC}"; }

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found"
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot access Kubernetes cluster"
        exit 1
    fi
    
    # Check GPU nodes
    GPU_NODES=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity."nvidia.com/gpu" != null) | .metadata.name' 2>/dev/null)
    if [ -z "$GPU_NODES" ]; then
        print_error "No GPU nodes found"
        exit 1
    fi
    
    TOTAL_GPUS=$(kubectl get nodes -o json | jq -r '[.items[].status.capacity."nvidia.com/gpu" // "0" | tonumber] | add' 2>/dev/null)
    if [ "$TOTAL_GPUS" -lt 4 ]; then
        print_error "Need at least 4 GPUs (found $TOTAL_GPUS)"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
    echo "  📍 Total GPUs: $TOTAL_GPUS"
    echo "  📍 GPU Nodes: $GPU_NODES"
}

deploy_complete_system() {
    print_header "Deploying Complete Face Recognition System"
    
    print_info "Applying complete system manifest..."
    kubectl apply -f complete-face-recognition-system.yaml
    
    print_success "All resources created"
}

monitor_deployment() {
    print_header "Monitoring Deployment Progress"
    
    echo "⏳ Waiting for namespace to be ready..."
    kubectl wait --for=condition=Ready namespace/face-recognition-system --timeout=30s
    
    echo "⏳ Waiting for GPU backend pods..."
    for gpu_id in {0..3}; do
        echo "  📍 Checking GPU $gpu_id backend..."
        kubectl wait --for=condition=Ready pod -l gpu-id=gpu${gpu_id} -n face-recognition-system --timeout=300s
        print_success "GPU $gpu_id backend is ready"
    done
    
    echo "⏳ Waiting for supporting services..."
    kubectl wait --for=condition=Ready pod -l component=database -n face-recognition-system --timeout=180s
    kubectl wait --for=condition=Ready pod -l component=cache -n face-recognition-system --timeout=120s
    kubectl wait --for=condition=Ready pod -l component=frontend -n face-recognition-system --timeout=120s
    
    print_success "All services are ready"
}

show_system_status() {
    print_header "System Status Overview"
    
    echo "📦 All Pods:"
    kubectl get pods -n face-recognition-system -o wide
    
    echo ""
    echo "🌐 All Services:"
    kubectl get services -n face-recognition-system
    
    echo ""
    echo "🎯 GPU Backend Pods Specifically:"
    kubectl get pods -n face-recognition-system -l app=django-backend -o custom-columns="POD:.metadata.name,GPU-ID:.metadata.labels.gpu-id,NODE:.spec.nodeName,STATUS:.status.phase"
    
    echo ""
    echo "📊 Resource Usage:"
    kubectl top pods -n face-recognition-system 2>/dev/null || print_warning "Metrics server not available"
}

show_access_info() {
    print_header "Application Access Information"
    
    MASTER_IP=$(kubectl get nodes bluedove2-ms-7b98 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "MASTER_IP")
    WORKER_IP=$(kubectl get nodes bluedovve-ms-7b98 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "WORKER_IP")
    
    echo "🌐 Main Application URLs:"
    echo "========================"
    echo "Frontend:              http://$MASTER_IP:30999"
    echo "Backend Load Balancer: http://$MASTER_IP:30898"
    echo ""
    echo "🎯 GPU-Specific Backend Endpoints:"
    echo "=================================="
    echo "GPU 0 (RTX 2080 Ti):   http://$MASTER_IP:30801"
    echo "GPU 1 (RTX 2080 Ti):   http://$MASTER_IP:30802"
    echo "GPU 2 (RTX 2080 Super): http://$WORKER_IP:30803"
    echo "GPU 3 (RTX 2080 Super): http://$WORKER_IP:30804"
    echo ""
    echo "🎥 Video Streaming Endpoints:"
    echo "============================"
    echo "MediaMTX Primary:      rtsp://$WORKER_IP:30554"
    echo "MediaMTX Secondary:    rtsp://$WORKER_IP:30555"
    echo "MediaMTX Normal:       rtsp://$WORKER_IP:30556"
    echo ""
    echo "🔧 Monitoring & Debug:"
    echo "====================="
    echo "Celery Monitor:        http://$MASTER_IP:30555"
    echo ""
    echo "📊 Resource Distribution:"
    echo "========================"
    echo "🖥️ Master Node ($MASTER_IP) - GPU DEDICATED:"
    echo "  • Django Backend GPU 0 (RTX 2080 Ti) → :30801"
    echo "  • Django Backend GPU 1 (RTX 2080 Ti) → :30802"
    echo "  • [ONLY GPU BACKENDS - Maximum GPU Performance]"
    echo ""
    echo "⚙️ Worker Node ($WORKER_IP) - ALL OTHER SERVICES:"
    echo "  • Django Backend GPU 2 (RTX 2080 Super) → :30803"
    echo "  • Django Backend GPU 3 (RTX 2080 Super) → :30804"
    echo "  • PostgreSQL Database"
    echo "  • Redis Primary & Channels"
    echo "  • All MediaMTX Instances (3x)"
    echo "  • Janus Gateway"
    echo "  • COTURN Server"
    echo "  • Celery Workers (2x)"
    echo "  • React Frontend (2x)"
    echo ""
    echo "💡 Architecture Benefits:"
    echo "  ✅ Master node dedicated to GPU processing only"
    echo "  ✅ Worker node handles all support services"
    echo "  ✅ Maximum GPU memory available for AI models"
    echo "  ✅ No CPU competition on master node"
}

test_all_endpoints() {
    print_header "Testing All System Endpoints"
    
    MASTER_IP=$(kubectl get nodes bluedove2-ms-7b98 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
    WORKER_IP=$(kubectl get nodes bluedovve-ms-7b98 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
    
    echo "🧪 Testing Backend GPU Endpoints:"
    for gpu_id in {0..3}; do
        if [ $gpu_id -le 1 ]; then
            NODE_IP=$MASTER_IP
        else
            NODE_IP=$WORKER_IP
        fi
        
        PORT=$((30801 + gpu_id))
        echo -n "  GPU $gpu_id ($NODE_IP:$PORT): "
        
        if curl -s --connect-timeout 5 "$NODE_IP:$PORT/health/" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ HEALTHY${NC}"
        else
            echo -e "${RED}❌ NOT RESPONDING${NC}"
        fi
    done
    
    echo ""
    echo "🧪 Testing Other Services:"
    echo -n "  Frontend ($MASTER_IP:30999): "
    if curl -s --connect-timeout 5 "$MASTER_IP:30999" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
    else
        echo -e "${RED}❌ NOT RESPONDING${NC}"
    fi
    
    echo -n "  Load Balancer ($MASTER_IP:30898): "
    if curl -s --connect-timeout 5 "$MASTER_IP:30898/health/" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
    else
        echo -e "${RED}❌ NOT RESPONDING${NC}"
    fi
}

show_logs() {
    local component=$1
    local gpu_id=$2
    
    print_header "Showing Logs for $component"
    
    case $component in
        "backend")
            if [ -n "$gpu_id" ]; then
                kubectl logs -n face-recognition-system deployment/django-backend-gpu$gpu_id --tail=50
            else
                echo "Usage: $0 logs backend <gpu_id>"
                echo "Example: $0 logs backend 0"
            fi
            ;;
        "frontend")
            kubectl logs -n face-recognition-system deployment/react-frontend --tail=50
            ;;
        "database")
            kubectl logs -n face-recognition-system deployment/postgresql-database --tail=50
            ;;
        "redis")
            kubectl logs -n face-recognition-system deployment/redis-primary --tail=50
            ;;
        "celery")
            kubectl logs -n face-recognition-system deployment/celery-worker --tail=50
            ;;
        "mediamtx")
            kubectl logs -n face-recognition-system deployment/mediamtx-primary --tail=50
            ;;
        *)
            echo "Available components: backend, frontend, database, redis, celery, mediamtx"
            echo "For backend, specify GPU ID: $0 logs backend <gpu_id>"
            ;;
    esac
}

scale_component() {
    local component=$1
    local replicas=$2
    local gpu_id=$3
    
    if [ -z "$component" ] || [ -z "$replicas" ]; then
        echo "Usage: $0 scale <component> <replicas> [gpu_id]"
        echo "Components: backend, frontend, celery, mediamtx"
        echo "For backend, specify GPU ID: $0 scale backend 2 0"
        return 1
    fi
    
    print_header "Scaling $component to $replicas replicas"
    
    case $component in
        "backend")
            if [ -n "$gpu_id" ]; then
                kubectl scale deployment django-backend-gpu$gpu_id --replicas=$replicas -n face-recognition-system
                print_success "Scaled GPU $gpu_id backend to $replicas replicas"
            else
                # Scale all GPU backends
                for gpu_id in {0..3}; do
                    kubectl scale deployment django-backend-gpu$gpu_id --replicas=$replicas -n face-recognition-system
                done
                print_success "Scaled all GPU backends to $replicas replicas"
            fi
            ;;
        "frontend")
            kubectl scale deployment react-frontend --replicas=$replicas -n face-recognition-system
            print_success "Scaled frontend to $replicas replicas"
            ;;
        "celery")
            kubectl scale deployment celery-worker --replicas=$replicas -n face-recognition-system
            print_success "Scaled celery workers to $replicas replicas"
            ;;
        "mediamtx")
            kubectl scale deployment mediamtx-primary --replicas=$replicas -n face-recognition-system
            kubectl scale deployment mediamtx-secondary --replicas=$replicas -n face-recognition-system
            print_success "Scaled MediaMTX instances to $replicas replicas"
            ;;
        *)
            print_error "Unknown component: $component"
            return 1
            ;;
    esac
}

cleanup_system() {
    print_header "Cleaning Up Complete System"
    
    print_warning "This will delete ALL face recognition system resources!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        kubectl delete namespace face-recognition-system --ignore-not-found=true
        print_success "Complete system cleaned up"
        
        echo ""
        echo "🔄 GPU Resources After Cleanup:"
        kubectl describe nodes | grep -A 3 "nvidia.com/gpu" || echo "No GPU info available"
    else
        print_info "Cleanup cancelled"
    fi
}

show_gpu_utilization() {
    print_header "Real-time GPU Utilization"
    
    echo "📊 GPU Backend Pods Distribution:"
    kubectl get pods -n face-recognition-system -l app=django-backend -o custom-columns="POD:.metadata.name,GPU-ID:.metadata.labels.gpu-id,NODE:.spec.nodeName,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount"
    
    echo ""
    echo "🔍 Resource Usage by Component:"
    kubectl top pods -n face-recognition-system --sort-by=cpu 2>/dev/null || print_warning "Metrics server not available"
    
    echo ""
    echo "📈 Node-level GPU Allocation:"
    kubectl describe nodes | grep -A 5 -B 2 "nvidia.com/gpu"
    
    echo ""
    echo "💾 Memory Usage by Node:"
    kubectl top nodes 2>/dev/null || print_warning "Node metrics not available"
}

generate_frontend_config() {
    print_header "Generating Frontend Configuration"
    
    MASTER_IP=$(kubectl get nodes bluedove2-ms-7b98 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
    WORKER_IP=$(kubectl get nodes bluedovve-ms-7b98 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
    
    cat > frontend-gpu-config.json << EOF
{
  "gpu_endpoints": {
    "0": {
      "name": "GPU 0 - RTX 2080 Ti (Master)",
      "endpoint": "http://$MASTER_IP:30801",
      "node": "master",
      "gpu_type": "RTX 2080 Ti",
      "memory": "11GB",
      "description": "High-memory GPU for complex models"
    },
    "1": {
      "name": "GPU 1 - RTX 2080 Ti (Master)",
      "endpoint": "http://$MASTER_IP:30802",
      "node": "master", 
      "gpu_type": "RTX 2080 Ti",
      "memory": "11GB",
      "description": "High-memory GPU for complex models"
    },
    "2": {
      "name": "GPU 2 - RTX 2080 Super (Worker)",
      "endpoint": "http://$WORKER_IP:30803",
      "node": "worker",
      "gpu_type": "RTX 2080 Super", 
      "memory": "8GB",
      "description": "Efficient GPU for standard processing"
    },
    "3": {
      "name": "GPU 3 - RTX 2080 Super (Worker)",
      "endpoint": "http://$WORKER_IP:30804",
      "node": "worker",
      "gpu_type": "RTX 2080 Super",
      "memory": "8GB", 
      "description": "Efficient GPU for standard processing"
    }
  },
  "load_balancer": "http://$MASTER_IP:30898",
  "frontend_url": "http://$MASTER_IP:30999"
}
EOF
    
    print_success "Frontend configuration saved to frontend-gpu-config.json"
    echo "Include this in your React frontend to configure GPU selection"
}

# Main execution
case "${1:-}" in
    "deploy")
        check_prerequisites
        deploy_complete_system
        monitor_deployment
        show_access_info
        ;;
    "status")
        show_system_status
        ;;
    "info")
        show_access_info
        ;;
    "test")
        test_all_endpoints
        ;;
    "logs")
        show_logs $2 $3
        ;;
    "scale")
        scale_component $2 $3 $4
        ;;
    "monitor")
        show_gpu_utilization
        ;;
    "config")
        generate_frontend_config
        ;;
    "cleanup")
        cleanup_system
        ;;
    *)
        print_header "Complete Face Recognition System Manager"
        echo "🎯 Available Commands:"
        echo "====================="
        echo "deploy    - Deploy complete 4-GPU system"
        echo "status    - Show system status"
        echo "info      - Show access URLs and endpoints"
        echo "test      - Test all endpoint connectivity"
        echo "logs      - Show logs for component"
        echo "scale     - Scale component replicas"
        echo "monitor   - Show GPU utilization"
        echo "config    - Generate frontend configuration"
        echo "cleanup   - Remove complete system"
        echo ""
        echo "Examples:"
        echo "  $0 deploy                    # Deploy everything"
        echo "  $0 logs backend 0           # Show GPU 0 backend logs"
        echo "  $0 scale backend 2 1        # Scale GPU 1 backend to 2 replicas"
        echo "  $0 test                     # Test all endpoints"
        echo "  $0 config                   # Generate frontend config"
        exit 1
        ;;
esac