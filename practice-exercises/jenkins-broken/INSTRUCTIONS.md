# Jenkins Troubleshooting Practice

This directory contains intentionally broken Jenkinsfiles for practice.

## How to Use

1. Try to identify bugs by reading the code
2. Check your answers in `SOLUTIONS.md`
3. Each file has a specific type of problem

## Files

| File | Difficulty | Bug Type |
|------|------------|----------|
| `01-syntax-error.jenkinsfile` | Easy | Basic syntax |
| `02-missing-steps.jenkinsfile` | Easy | Structure |
| `03-wrong-conditional.jenkinsfile` | Medium | Logic |
| `04-credentials-issue.jenkinsfile` | Medium | Security |
| `05-docker-issue.jenkinsfile` | Hard | Integration |

## Practice Strategy

1. **Read the error messages** - Jenkins gives useful hints
2. **Check structure** - pipeline → agent → stages → stage → steps
3. **Validate quotes** - `'single'` vs `"double ${VAR}"`
4. **Test locally** - Use Jenkins Pipeline Linter if available
