data "aws_eks_cluster" "example" {
  name = "nextcluster"
}
# output "identity-oidc-issuer" {
#   value = trimprefix(data.aws_eks_cluster.example.identity[0].oidc[0].issuer,"https://oidc.eks.us-east-1.amazonaws.com/id/")
# }

# output "endpoint" {
#   value = data.aws_eks_cluster.example.endpoint
# }

# output "certbody"{
#   value = data.aws_eks_cluster.example.certificate_authority[0].data
# }

locals {
  oidcval = trimprefix(data.aws_eks_cluster.example.identity[0].oidc[0].issuer,"https://oidc.eks.us-east-1.amazonaws.com/id/")
  awsacc = "657907747545"
  region = "us-east-1"
}

resource "aws_iam_role" "eks-ebs-csi-diver" {
  name = data.aws_eks_cluster.example.id
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${local.awsacc}:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/${local.oidcval}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${local.region}.amazonaws.com/id/${local.oidcval}:aud": "sts.amazonaws.com",
          "oidc.eks.${local.region}.amazonaws.com/id/${local.oidcval}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks-ebs-policy-attachment" {
    role = "${aws_iam_role.eks-ebs-csi-diver.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "eks-ebs-policy_custom-attachment" {
    role = "${aws_iam_role.eks-ebs-csi-diver.name}"
    policy_arn = "arn:aws:iam::657907747545:policy/AmazonEKS_EBS_CSI_Driver_Policy"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.example.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.example.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.example.id]
  }
}

# resource "kubernetes_annotations" "ebs_annotate" {
#   api_version = "v1"
#   kind        = "serviceaccount"
#   metadata {
#     name = "ebs-csi-controller-sa"
#     namespace = "kube-system"
#   }
#   annotations = {
#     "eks.amazonaws.com/role-arn" = "${aws_iam_role.eks-ebs-csi-diver.arn}"
#   }
# }


resource "null_resource" "clustert" {
  provisioner "local-exec" {
    command = "kubectl.exe annotate serviceaccount ebs-csi-controller-sa -n kube-system --overwrite=true eks.amazonaws.com/role-arn=${aws_iam_role.eks-ebs-csi-diver.arn}"
  }
}