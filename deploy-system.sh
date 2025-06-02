#!/bin/bash

# Face Recognition System - Split File Deployment Script
# Deploys from separate YAML files for better organization

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

check_files() {
    print_header "Checking Required Files"
    
    local files=(
        "01-namespace-and-config.yaml"
        "02-gpu-backends.yaml"
        "03-database-redis.yaml"
        "04-web-services.yaml"
        "05-streaming-services.yaml"
        "06-services.yaml"
        "07-autoscaling-monitoring.yaml"
    )
    
    local missing_files=()
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_success "Found: $file"
        else
            print_error "Missing: $file"
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "Missing required files. Please ensure all YAML files are present."
        exit 1
    fi
    
    print_success "All required files found"
}

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

deploy_step() {
    local step_num=$1
    local step_name=$2
    local file_name=$3
    
    print_info "Step $step_num: Deploying $step_name"
    kubectl apply -f "$file_name"
    
    if [ $? -eq 0 ]; then
        print_success "$step_name deployed successfully"
    else
        print_error "Failed to deploy $step_name"
        exit 1
    fi
    
    sleep 2  # Brief pause between deployments
}

deploy_complete_system() {
    print_header "Deploying Complete Face Recognition System"
    
    # Step 1: Namespace and Configuration
    deploy_step 1 "Namespace and Configuration" "01-namespace-and-config.yaml"
    
    # Step 2: GPU Backend Deployments
    deploy_step 2 "GPU Backend Services" "02-gpu-backends.yaml"
    
    # Step 3: Database and Redis
    deploy_step 3 "Database and Redis Services" "03-database-redis.yaml"
    
    # Step 4: Web Services
    deploy_step 4 "Frontend and Celery Services" "04-web-services.yaml"
    
    # Step 5: Streaming Services
    deploy_step 5 "Streaming and Communication Services" "05-streaming-services.yaml"
    
    # Step 6: Kubernetes Services
    deploy_step 6 "Kubernetes Services and Networking" "06-services.yaml"
    
    # Step 7: Monitoring and Autoscaling
    deploy_step 7 "Monitoring and Autoscaling" "07-autoscaling-monitoring.yaml"
    
    print_success "All components deployed successfully"
}

wait_for_pods() {
    print_header "Waiting for Pods to be Ready"
    
    echo "⏳ Waiting for namespace to be ready..."
    kubectl wait --for=condition=Ready namespace/face-recognition-system --timeout=30s || true
    
    echo "⏳ Waiting for GPU backend pods..."
    for gpu_id in {0..3}; do
        echo "  📍 Checking GPU $gpu_id backend..."
        kubectl wait --for=condition=Ready pod -l gpu-id=gpu${gpu_id} -n face-recognition-system --timeout=300s || print_warning "GPU $gpu_id backend not ready yet"
    done
    
    echo "⏳ Waiting for database..."
    kubectl wait --for=condition=Ready pod -l app=postgresql -n face-recognition-system --timeout=180s || print_warning "Database not ready yet"
    
    echo "⏳ Waiting for Redis services..."
    kubectl wait --for=condition=Ready pod -l app=redis-primary -n face-recognition-system --timeout=120s || print_warning "Redis not ready yet"
    
    echo "⏳ Waiting for frontend..."
    kubectl wait --for=condition=Ready pod -l app=react-frontend -n face-recognition-system --timeout=120s || print_warning "Frontend not ready yet"
    
    print_success "Pod startup monitoring completed"
}

show_system_status() {
    print_header "System Status Overview"
    
    echo "📦 All Pods:"
    kubectl get pods -n face-recognition-system -o wide
    
    echo ""
    echo "🌐 All Services:"
    kubectl get services -n face-recognition-system
    
    echo ""
    echo "🎯 GPU Backend Status:"
    kubectl get pods -n face-recognition-system -l app=django-backend -o custom-columns="POD:.metadata.name,GPU-ID:.metadata.labels.gpu-id,NODE:.spec.nodeName,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount"
}

show_access_info() {
    print_header "Application Access Information"
    
    # Get master node IP (adjust node name as needed)
    MASTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [ -z "$MASTER_IP" ]; then
        MASTER_IP="<CLUSTER_IP>"
        print_warning "Could not determine master node IP automatically"
    fi
    
    # Get service ports
    FRONTEND_PORT=$(kubectl get service react-frontend-service -n face-recognition-system -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30080")
    BACKEND_PORT=$(kubectl get service django-backend-service -n face-recognition-system -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30000")
    STREAM_PORT=$(kubectl get service streaming-service -n face-recognition-system -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30081")
    
    echo ""
    echo "🌐 Access URLs:"
    echo "  📱 Frontend:     http://${MASTER_IP}:${FRONTEND_PORT}"
    echo "  🔧 Backend API:  http://${MASTER_IP}:${BACKEND_PORT}"
    echo "  📺 Streaming:    http://${MASTER_IP}:${STREAM_PORT}"
    echo ""
    echo "🔍 Monitoring:"
    echo "  📊 Kubernetes Dashboard: kubectl proxy (http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)"
    echo "  📈 Pod Logs: kubectl logs -f <pod-name> -n face-recognition-system"
    echo ""
    echo "🛠️  Useful Commands:"
    echo "  kubectl get pods -n face-recognition-system -w"
    echo "  kubectl logs -f deployment/react-frontend -n face-recognition-system"
    echo "  kubectl logs -f deployment/django-backend-gpu0 -n face-recognition-system"
}

cleanup_system() {
    print_header "Cleanup System"
    print_warning "This will delete the entire face recognition system"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        print_info "Deleting all resources..."
        kubectl delete namespace face-recognition-system --grace-period=0 --force 2>/dev/null || true
        print_success "System cleaned up"
    else
        print_info "Cleanup cancelled"
    fi
}

show_help() {
    print_header "Face Recognition System Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     Deploy the complete system (default)"
    echo "  status     Show system status"
    echo "  cleanup    Remove the entire system"
    echo "  check      Check prerequisites only"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy    # Deploy the complete system"
    echo "  $0 status    # Check current system status"
    echo "  $0 cleanup   # Remove everything"
    echo ""
}

main() {
    local command=${1:-deploy}
    
    case $command in
        deploy)
            check_files
            check_prerequisites
            deploy_complete_system
            wait_for_pods
            show_system_status
            show_access_info
            ;;
        status)
            show_system_status
            show_access_info
            ;;
        cleanup)
            cleanup_system
            ;;
        check)
            check_files
            check_prerequisites
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"