terraform {
  cloud {
    organization = "gtis"
    workspaces {
      name = "op-connect-stg"
    }
  }
}
