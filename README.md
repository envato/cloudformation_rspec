# CloudSpec

CloudFormation provides a black-box orchestration model; you feed templates in and infrastructure pops out the other end. This is good in that we design our templates without having to understand how the sausage gets made, but we want a way to test, quickly, what it's actually doing is what we expect.

CloudSpec enables us to do that by providing RSpec matchers to enable you to test your templates against the actual CloudFormation APIs to make sure they work.
