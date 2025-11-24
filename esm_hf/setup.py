#!/usr/bin/env python3
# Setup script for ESM HuggingFace package

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as f:
    long_description = f.read()

# Core dependencies
install_requires = [
    "torch>=1.12.0",
    "transformers>=4.30.0",
    "accelerate>=0.20.0",
    "biopython",
]

# Optional dependency groups
extras_require = {
    "dev": [
        "pytest>=7.0.0",
        "pytest-cov>=4.0.0",
        "black>=23.0.0",
        "flake8>=6.0.0",
        "isort>=5.12.0",
        "mypy>=1.0.0",
        "ipython>=8.0.0",
    ],
    "jupyter": [
        "jupyter>=1.0.0",
        "py3Dmol",
    ],
}

extras_require["all"] = list(set(sum(extras_require.values(), [])))

setup(
    name="esm-hf",
    version="1.0.0",
    author="ESMFold HuggingFace Contributors",
    author_email="",
    description="ESMFold protein structure prediction using HuggingFace Transformers",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/facebookresearch/esm",
    packages=find_packages(),
    package_dir={"": "."},
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
        "Topic :: Scientific/Engineering :: Bio-Informatics",
    ],
    python_requires=">=3.8",
    install_requires=install_requires,
    extras_require=extras_require,
    entry_points={
        "console_scripts": [
            "esm-fold-hf=scripts.hf_fold:main",
        ],
    },
    include_package_data=True,
    zip_safe=False,
)
