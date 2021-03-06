# posterior predictions
rm(list=ls())
load("../ozone_data.RData")

# preprocessing
x <- x / 1000
y <- y / 1000

# get the locations of
S.p <- expand.grid(x, y)
keep.these <- (S.p[, 1] > 1.03 & S.p[, 1] < 1.7) &
  (S.p[, 2] > -0.96 & S.p[, 2] < -0.40)
S.p     <- S.p[keep.these, ]
nx <- length(unique(S.p[, 1]))
ny <- length(unique(S.p[, 2]))
nt <- dim(Y)[2]
threshold <- 75

# 1 knot - No Time Series - T = 0
load('us-all-pred-3.RData')
yp <- y.pred
np <- dim(yp)[2]
niters <- dim(yp)[1]

# get the posterior distribution of the 95th and 99th quantile for each site
print("getting q95")
set.3.95.q <- apply(yp, c(1, 2), quantile, probs = 0.95)
print("getting q99")
set.3.99.q <- apply(yp, c(1, 2), quantile, probs = 0.99)
# set.3.95 <- apply(yp, c(2), quantile, probs=0.95)
# set.3.99 <- apply(yp, c(2), quantile, probs=0.99)
set.3.95 <- apply(set.3.95.q, 2, mean)
set.3.99 <- apply(set.3.99.q, 2, mean)

print("getting probs of exceedance")
set.3.p.below <- matrix(0, np, nt)
for (i in 1:np) { for (t in 1:nt) {
  set.3.p.below[i, t] <- mean(yp[, i, t] <= threshold)
} }
set.3.p.0 <- rep(0, np)
for(i in 1:np) {
  set.3.p.0[i] <- prod(set.3.p.below[i, ])
}
set.3.p.1 <- rep(0, np)
for (i in 1:np) { for (t in 1:nt) {
  set.3.p.1[i] <- set.3.p.1[i] + prod(set.3.p.below[i, -t]) *
    (1 - set.3.p.below[i, t])
} }
set.3.p.2 <- rep(0, np)
for(i in 1:np) { for (t in 1:(nt - 1)) {
  for (s in (t+1):nt) {
    set.3.p.2[i] <- set.3.p.2[i] + prod(set.3.p.below[i, -c(s,t)]) *
      prod(1 - set.3.p.below[i, c(s, t)])
  }
}}
set.3.p.atleast1 <- 1 - set.3.p.0
set.3.p.atleast2 <- 1 - (set.3.p.0 + set.3.p.1)
set.3.p.atleast3 <- 1 - (set.3.p.0 + set.3.p.1 + set.3.p.2)


rm(y.pred)
rm(yp)
save.image(file="predict-maps-3.RData")