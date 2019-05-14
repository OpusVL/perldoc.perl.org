.PHONY: clean dist docker

docker:
	docker build \
        --no-cache \
		-t quay.io/opusvl/perldoc:latest .

release: docker
	docker tag quay.io/opusvl/perldoc:latest quay.io/opusvl/perldoc:release \
	&& docker push quay.io/opusvl/perldoc:release

push: release
	docker push quay.io/opusvl/perldoc:latest

