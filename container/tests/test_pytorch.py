import torch

print("✅ PyTorch version:", torch.__version__)

# Check if CUDA is available
if torch.cuda.is_available():
    print("✅ CUDA is available")
    print("  - CUDA device count:", torch.cuda.device_count())
    print("  - Current device:", torch.cuda.current_device())
    print("  - Device name:", torch.cuda.get_device_name(0))
    
    # Test a simple tensor operation on GPU
    x = torch.rand(3, 3).cuda()
    y = torch.rand(3, 3).cuda()
    z = x + y
    print("✅ Tensor operation successful on GPU:")
    print(z)
else:
    print("❌ CUDA is NOT available. Using CPU.")
    x = torch.rand(3, 3)
    y = torch.rand(3, 3)
    z = x + y
    print("✅ Tensor operation successful on CPU:")
    print(z)
