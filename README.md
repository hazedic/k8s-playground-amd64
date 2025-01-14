# k8s-playground-amd64

## Usage

```sh
$ git clone https://github.com/hazedic/k8s-playground-amd64.git
$ cd k8s-playgound-amd64
$ pushd k8s
$ vagrant up
$ popd
$ pushd hk8s
$ vagrant up
$ popd
```

## Clusters

| Cluster | Members            | CNI     | Description |
| ------- | ------------------ | ------- | ----------- |
| k8s     | 1 master, 2 worker | flannel | k8s cluster |
| hk8s    | 1 master, 2 worker | calico  | k8s cluster |

## License

Provided under the terms of the [MIT License](https://github.com/hazedic/k8s-playground-amd64/blob/master/LICENSE).

Copyright © 2025, [JaeRyoung Oh](https://www.tralixis.com).