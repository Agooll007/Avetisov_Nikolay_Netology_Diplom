variable "vpc_name" {
  description = "Имя VPC сети"
  default     = "diploma-vpc"
}

variable "subnet_name" {
  description = "Базовое имя подсетей"
  default     = "diploma-subnet"
}

variable "zone_1" {
  description = "Первая зона"
  default     = "ru-central1-a"
}

variable "zone_2" {
  description = "Вторая зона"
  default     = "ru-central1-b"
}