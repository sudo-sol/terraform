resource "aws_db_subnet_group" "orders" {
  name       = local.name
  subnet_ids = module.network.private_subnets
}

resource "aws_db_instance" "orders" {
  identifier                          = local.name
  engine                              = "postgres"
  engine_version                      = "16"
  instance_class                      = "db.t4g.small"
  allocated_storage                   = 20
  storage_type                        = "gp3"
  storage_encrypted                   = true
  db_name                             = "orders"
  username                            = "migration_admin"
  manage_master_user_password         = true
  iam_database_authentication_enabled = true
  db_subnet_group_name                = aws_db_subnet_group.orders.name
  vpc_security_group_ids              = [aws_security_group.tier["db"].id]
  publicly_accessible                 = false
  multi_az                            = false
  backup_retention_period             = 1
  skip_final_snapshot                 = true
}
