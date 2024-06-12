# Build Zero-bin Docker Images

Clone the repository.

```bash
git clone git@github.com:0xPolygonZero/zero-bin.git
cd zero-bin
```

Build the leader image.

```bash
patch -p1 -i ../leader.diff
docker build --tag leovct/zero-bin-leader:develop --file leader.Dockerfile .
docker push leovct/zero-bin-leader:develop
```

Build the worker image.

```bash
patch -p1 -i ../worker.diff
docker build --tag leovct/zero-bin-worker:develop --file worker.Dockerfile .
docker push leovct/zero-bin-worker:develop
```
