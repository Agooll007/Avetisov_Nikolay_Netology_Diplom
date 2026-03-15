terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.103"
    }
  }
}

provider "yandex" {
  service_account_key_file = "../key.json"
  cloud_id                 = "b1gu8nr2dtqe42t3dau2"
  folder_id                = "b1g8gc081311qipdok4c"
  zone                     = "ru-central1-a"
}
