{
  "variables": {
    "aws_region": "us-west-2",
    "ami_name": "eks-k8s-worker-cis-${OS}-${VERSION}-ami-{{timestamp}}",
    "binary_bucket_name": "amazon-eks",
    "binary_bucket_region": "us-west-2",
    "binary_bucket_path": "${KUBERNETES_VERSION}/2018-12-06/bin/linux/amd64",
    "build_subnet": "${BUILD_SUBNET}",
    "creator": "{{env `USER`}}",
    "instance_type": "m4.large"
  },
  "builders": [
    {
      "type": "amazon-ebs",
      "region": "{{user `aws_region`}}",
      "source_ami": "{{user `source_ami_id`}}",
      "instance_type": "{{user `instance_type`}}",
      "launch_block_device_mappings": [
        {
          "device_name": "/dev/xvda",
          "volume_type": "gp2",
          "volume_size": 20,
          "delete_on_termination": true
        }
      ],
      "ssh_username": "{{ user `ssh_user` }}",
      "ssh_pty": true,
      "run_tags": {
          "creator": "{{user `creator`}}"
      },
      "tags": {
          "created": "{{timestamp}}"
      },
      "ami_name": "{{user `ami_name`}}",
      "ami_description": "EKS Kubernetes Worker AMI with ${OS} ${VERSION} image",
      "subnet_id": "{{ user `build_subnet`}}"
    }
  ],
  "provisioners": [
    {
      "type": "shell",
      "inline": ["mkdir -p /tmp/worker/"]
    },
    {
      "type": "file",
      "source": "./files/",
      "destination": "/tmp/worker/"
    },
    {
      "type": "shell",
      "script": "install-worker.sh",
      "environment_vars": [
        "AMI_NAME={{user `ami_name`}}",
        "BINARY_BUCKET_NAME={{user `binary_bucket_name`}}",
        "BINARY_BUCKET_PATH={{user `binary_bucket_path`}}",
        "BINARY_BUCKET_REGION={{user `binary_bucket_region`}}",
        "OS=${OS}",
        "VERSION=${VERSION}"
      ]
    },
    {
        "type": "shell",
        "inline": [
            "sudo pip install ansible"
        ]
    }, 
    {
        "type": "ansible-local",
        "playbook_file": "ansible/${OS}.yaml",
        "role_paths": [
            "ansible/roles/common"
        ],
        "playbook_dir": "ansible"
    },
    {
      "type": "shell",
      "inline": [
        "rm .ssh/authorized_keys ; sudo rm /root/.ssh/authorized_keys"
      ]
    }
  ],
  "post-processors": [
    {
      "type": "manifest",
      "output": "${OS}-${VERSION}-manifest.json",
      "strip_path": true
    }
  ]
}
