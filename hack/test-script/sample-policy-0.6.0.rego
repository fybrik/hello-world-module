package dataapi.authz

description := "allow the write operation"
rule[{}] {
  input.action.actionType == "write"
  true
}