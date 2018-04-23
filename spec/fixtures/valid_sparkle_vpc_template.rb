SparkleFormation.new(:vpc) do
  resources.vpc do
    type "AWS::EC2::VPC"
    properties do
      cidr "10.0.0.0/16"
    end
  end
end
