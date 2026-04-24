resource "aws_vpc" "new" {
  count      = var.use_existing_vpc ? 0 : 1
  cidr_block = var.vpc_cidr
  tags       = { Name = var.vpc_name }
}

data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  tags  = { Name = "existing-vpc" }
}

# All networking below is only created when we own the VPC
resource "aws_internet_gateway" "igw" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = local.vpc_id
  tags   = { Name = "main-igw" }
}

resource "aws_subnet" "public" {
  for_each = var.use_existing_vpc ? {} : var.public_subnets

  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 10)
  availability_zone       = data.aws_availability_zones.available.names[each.value % 3]
  map_public_ip_on_launch = true
  tags                    = { Name = each.key }
}

resource "aws_subnet" "private" {
  for_each = var.use_existing_vpc ? {} : var.private_subnets

  vpc_id            = local.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = data.aws_availability_zones.available.names[each.value % 3]
  tags              = { Name = each.key }
}

resource "aws_route_table" "public" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat_eip" {
  count  = var.use_existing_vpc ? 0 : 1
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.cluster_name}-nat-eip" })
}

resource "aws_nat_gateway" "main_nat" {
  count         = var.use_existing_vpc ? 0 : 1
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.public[keys(aws_subnet.public)[0]].id
  tags          = merge(local.common_tags, { Name = "${var.cluster_name}-nat" })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat[0].id
  }
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-private-rt" })
}

resource "aws_route_table_association" "private_assoc" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[0].id
}
