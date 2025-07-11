# CI/CD Pipeline Documentation

## Overview

The rpi-os-installer project includes a comprehensive CI/CD pipeline that automatically validates all code changes through multiple stages of testing and security scanning. This ensures consistent quality and prevents security vulnerabilities from entering the codebase.

## Pipeline Triggers

The CI pipeline runs automatically on:
- **Pull Requests** to `main` or `develop` branches
- **Push events** to `main` or `develop` branches  
- **Manual triggers** via GitHub Actions web interface

## Pipeline Stages

### 1. ShellCheck Validation
- **Purpose**: Validates all shell scripts for syntax errors, best practices, and common pitfalls
- **Scope**: All `.sh` files in the repository
- **Criteria**: All scripts must pass ShellCheck with no errors or warnings

### 2. Build Process Validation
- **Purpose**: Ensures the project can be built successfully
- **Tests**:
  - Makefile targets functionality
  - System dependency installation
  - OS setup script generation
  - Generated script validation
- **Artifacts**: Validates generated scripts with ShellCheck

### 3. Testing Framework Validation
- **Purpose**: Validates the testing infrastructure works correctly
- **Tests**:
  - Testing framework setup (QEMU, Docker)
  - Setup test execution
  - Validation script execution
- **Dependencies**: Installs QEMU and Docker for comprehensive testing

### 4. Security Scanning
- **Purpose**: Identifies potential security vulnerabilities
- **Scans**:
  - **Hardcoded secrets**: Detects password, API keys, tokens
  - **Dangerous commands**: Identifies unsafe `rm -rf` patterns
  - **Device paths**: Checks for hardcoded device paths
  - **File permissions**: Validates executable permissions

### 5. Integration Testing
- **Purpose**: Tests the complete workflow end-to-end
- **Process**:
  - Runs full build process
  - Validates all generated scripts
  - Confirms integration between components

### 6. Documentation Validation
- **Purpose**: Ensures required documentation is present and valid
- **Checks**:
  - Required documentation files exist
  - Internal links validation
  - Documentation completeness

## Security Features

### Hardcoded Secret Detection
```bash
# GOOD - Uses environment variables
API_KEY="$TAVILY_API_KEY"

# BAD - Hardcoded secret (detected by CI)
API_KEY="sk-1234567890abcdef"
```

### Safe Command Patterns
```bash
# GOOD - Protected variable expansion
rm -rf "${mount_point:?}"/*

# BAD - Unsafe pattern (detected by CI)
rm -rf $mount_point/*
```

### Device Path Safety
```bash
# GOOD - Dynamic device detection
TARGET_DEVICE=$(detect_target_device)

# BAD - Hardcoded device path (detected by CI)
TARGET_DEVICE="/dev/nvme0n1"
```

## Quality Gates

The pipeline implements several quality gates:

1. **Zero ShellCheck Issues**: All scripts must pass ShellCheck validation
2. **Successful Build**: The project must build without errors
3. **Working Tests**: All testing frameworks must be functional
4. **Security Compliance**: No security vulnerabilities detected
5. **Integration Success**: Complete workflow must execute successfully
6. **Documentation Complete**: Required documentation must be present

## Failure Handling

When the pipeline fails:

1. **Review the failed stage** in GitHub Actions
2. **Check the detailed logs** for specific error messages
3. **Fix the identified issues** locally
4. **Test the fixes** using local commands:
   ```bash
   # Run shellcheck locally
   find . -name "*.sh" -type f -print0 | xargs -0 shellcheck
   
   # Test build process
   make generate
   
   # Run validation
   make validate
   ```
5. **Commit and push** the fixes to trigger a new pipeline run

## Local Development

To run similar checks locally before pushing:

```bash
# Quick validation
make validate

# ShellCheck all scripts
find . -name "*.sh" -type f -print0 | xargs -0 shellcheck

# Test build process
make generate

# Run setup tests
make test-setup
```

## Pipeline Configuration

The CI pipeline is configured in `.github/workflows/ci.yml` and includes:

- **Parallel execution** for faster feedback
- **Comprehensive dependencies** for realistic testing
- **Detailed reporting** with success/failure summaries
- **Security scanning** to prevent vulnerabilities
- **Integration testing** to validate complete workflows

## Monitoring and Maintenance

### Pipeline Health
- Monitor pipeline success rates in GitHub Actions
- Review failed builds promptly
- Update dependencies regularly

### Security Updates
- Review security scan results
- Update scanning patterns as needed
- Monitor for new vulnerability types

### Performance Optimization
- Monitor pipeline execution time
- Optimize slow stages
- Cache dependencies where possible

## Best Practices

1. **Always run local validation** before pushing
2. **Keep commits focused** to make pipeline failures easier to debug
3. **Write descriptive commit messages** for pipeline history
4. **Monitor pipeline status** after pushing changes
5. **Fix pipeline failures promptly** to maintain code quality

## Troubleshooting

### Common Issues

**ShellCheck Failures**:
- Review shellcheck output for specific recommendations
- Use proper variable quoting: `"$variable"` not `$variable`
- Add shellcheck disable comments only when necessary

**Build Failures**:
- Check system dependencies
- Verify file permissions
- Ensure proper directory structure

**Security Scan Failures**:
- Remove hardcoded secrets
- Use environment variables for sensitive data
- Validate command patterns for safety

**Integration Test Failures**:
- Check complete workflow execution
- Verify generated scripts are valid
- Ensure all dependencies are available

For additional help, review the pipeline logs in GitHub Actions or consult the project documentation.