
resource "tls_private_key" "task1_key" { 
  algorithm = "RSA"
}

resource "aws_key_pair" "task1_key" {
key_name = "task1_key"
public_key= tls_private_key.task1_key.public_key_openssh
}


resource "aws_security_group" "task1-http" {
  name        = "task1-http"
  description = "allow ssh and http"
  vpc_id = "vpc-baebf6d2"
ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


resource  "aws_instance"  "cloudtask1"   {
  ami = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "task1_key"
  security_groups = ["${aws_security_group.task1-http.name}"]
tags = {
        Name = "webserveros1"
  }


connection {
	type = "ssh"
	user = "ec2-user"
	private_key = tls_private_key.task1_key.private_key_pem
	host = aws_instance.cloudtask1.public_ip
}

provisioner "remote-exec"{
		
inline = [		
	"sudo yum install httpd git -y",
        "sudo systemctl restart httpd",
        "sudo systemctl enable httpd",   
	]
}
}


resource "aws_ebs_volume" "cloud_volume" {
depends_on = [	
       aws_instance.cloudtask1
  ]
availability_zone = aws_instance.cloudtask1.availability_zone
size  = 1
tags = {
    Name = "ebs_vol"
  }

}

resource "aws_volume_attachment" "ebs_attachment" {
depends_on = [
	aws_ebs_volume.cloud_volume
]

device_name = "/dev/sdh"
volume_id   = aws_ebs_volume.cloud_volume.id
instance_id = aws_instance.cloudtask1.id
}




resource "null_resource" "mount_partition"{
depends_on = [
	aws_volume_attachment.ebs_attachment
]
connection {
	type = "ssh"
	user = "ec2-user"
	private_key = tls_private_key.task1_key.private_key_pem
	host = aws_instance.cloudtask1.public_ip
   }
	
provisioner "remote-exec"{
inline = [
	"sudo mkfs.ext4 /dev/sdh",
        "sudo mount /dev/sdh /var/www/html",
	"sudo rm -rf /var/www/html/*",
	"sudo git clone https://github.com/shiviagarwal21/multi-cloud.git     /var/www/html"
	]
 }
}


resource "aws_s3_bucket" "shivi-cloud-task08" {
  bucket = "shivi-cloud-task08"
  acl    = "public-read"
  tags = {
	Name = "shivi-cloud-task08"
}
}

locals {
s3_origin_id = "S3Origin1"
}


resource "aws_s3_bucket_object" "shivi-cloud-task08" {

  bucket = "shivi-cloud-task08"
  key    = "image1.png"
  source = "C:/Users/shivi agarwal/Desktop/tera/local/image1.png"
}



resource "aws_cloudfront_distribution" "task1distribution" {
origin {
    domain_name = aws_s3_bucket.shivi-cloud-task08.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
custom_origin_config {
    	http_port = 80
    	https_port = 80
    	origin_protocol_policy = "match-viewer"
    	origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
    }
  }
enabled = true
default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
viewer_protocol_policy = "allow-all"
min_ttl = 0
default_ttl = 3600
max_ttl = 86400
}
restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
viewer_certificate {
    cloudfront_default_certificate = true  
}
}


