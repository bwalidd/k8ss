# Deploy the complete 4-GPU system
# ./complete-system-deploy.sh deploy

# Check system status
# ./complete-system-deploy.sh status

# Show access information and URLs
# ./complete-system-deploy.sh info

# Test all endpoints connectivity
# ./complete-system-deploy.sh test


# Monitor GPU utilization in real-time
# ./complete-system-deploy.sh monitor

# # Check logs for specific GPU backend
# ./complete-system-deploy.sh logs backend 0    # GPU 0 logs
# ./complete-system-deploy.sh logs backend 1    # GPU 1 logs
# ./complete-system-deploy.sh logs backend 2    # GPU 2 logs
# ./complete-system-deploy.sh logs backend 3    # GPU 3 logs

# # Check other service logs
# ./complete-system-deploy.sh logs frontend
# ./complete-system-deploy.sh logs database
# ./complete-system-deploy.sh logs redis
# ./complete-system-deploy.sh logs celery


# Scale specific GPU backend
# ./complete-system-deploy.sh scale backend 2 0    # Scale GPU 0 to 2 replicas
# ./complete-system-deploy.sh scale backend 1 1    # Scale GPU 1 to 1 replica

# # Scale other services
# ./complete-system-deploy.sh scale frontend 3     # Scale frontend to 3 replicas
# ./complete-system-deploy.sh scale celery 4       # Scale celery to 4 workers







#=----------------------------------------------------





# Step 1: Deploy everything
# echo "🚀 Starting complete deployment..."
# ./complete-system-deploy.sh deploy

# # Wait for deployment to complete, then check status
# echo "📊 Checking system status..."
# ./complete-system-deploy.sh status

# # Test all endpoints
# echo "🧪 Testing connectivity..."
# ./complete-system-deploy.sh test

# # Generate frontend configuration
# echo "⚙️ Generating frontend config..."
# ./complete-system-deploy.sh config

# # Show access information
# echo "🌐 Access information:"
# ./complete-system-deploy.sh info