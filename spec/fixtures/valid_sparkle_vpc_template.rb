SparkleFormation.new(:vpc) do
  resources.vpc do
    type "AWS::EC2::VPC"
    properties do
      cidr_block "10.0.0.0/16"
    end
  end

  outputs do
    vpc_id do
      value ref!(:vpc)
      description "The VPC ID"
    end

    vpc_cidr do
      value "10.0.0.0/16"
      description "The VPC CIDR"
    end
  end
end
