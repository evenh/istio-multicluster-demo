module "east" {
  source = "./modules/kubernetes"
  name   = "east"
  region = "nyc3"
  vpc_id = 80
}

module "east_config" {
  source     = "./modules/kubernetes-config"
  kubeconfig = module.east.kubeconfig
  name       = "east"
  region     = "nyc3"
}

module "west" {
  source = "./modules/kubernetes"
  name   = "west"
  region = "sfo3"
  vpc_id = 160
}

module "west_config" {
  source     = "./modules/kubernetes-config"
  kubeconfig = module.west.kubeconfig
  name       = "west"
  region     = "sfo3"
}

module "connect-multicluster" {
  source = "./modules/connect-multicluster"
  east_cluster = {
    name                      = module.east.name
    remote_reader_secret_name = module.east_config.remote_reader_secret_name
    kubeconfig                = module.east.kubeconfig
  }
  west_cluster = {
    name                      = module.west.name
    remote_reader_secret_name = module.west_config.remote_reader_secret_name
    kubeconfig                = module.west.kubeconfig
  }
}
