options(warn=2)
library(fields)
library(SpatialTools)
library(mvtnorm)

rm(list=ls())
load("../ozone_data.RData")
source('../../../R/mcmc.R', chdir=T)
source('../../../R/auxfunctions.R')
load("us-all-full-59.RData")

outputfile <- "us-all-pred-59.RData"

# preprocessing
x <- x / 1000
y <- y / 1000
CMAQ.cs <- (CMAQ - mean(CMAQ)) / sd(CMAQ)

# where did we actually observe ozone
S       <- cbind(x[s[, 1]], y[s[, 2]])  # expands the grid of x, y
excl    <- which(rowMeans(is.na(Y)) > 0.50)  # remove where we're missing 50%
index   <- index[-excl]
S.o     <- S[-excl, ]
cmaq.o  <- CMAQ.cs[index, ]

# where to make the predictions: southeast is in [1000, 2000] x [-1000, 0]
S.p <- expand.grid(x, y)
keep.these <- (S.p[, 1] > 1.03 & S.p[, 1] < 1.7) &
              (S.p[, 2] > -0.96 & S.p[, 2] < -0.40)
S.p     <- S.p[keep.these, ]
CMAQ.cs <- (CMAQ - mean(CMAQ)) / sd(CMAQ)
cmaq.p  <- CMAQ.cs[keep.these, ]

# nx      <- length(unique(S.p[, 1]))
# ny      <- length(unique(S.p[, 2]))
# quilt.plot(x=S.p[, 1], y=S.p[, 2], matrix(cmaq.p[, 20]), nx=nx, ny=ny)
# lines(borders / 1000)

nt <- ncol(cmaq.p)
np <- nrow(cmaq.p)
ns <- nrow(cmaq.o)
X.o <- array(1, dim=c(nrow(cmaq.o), nt, 2))
X.p <- array(1, dim=c(nrow(cmaq.p), nt, 2))
for (t in 1:nt) {
  X.p[, t, 2] <- cmaq.p[, t]
  X.o[, t, 2] <- cmaq.o[, t]
}

# preliminary setup
nreps     <- dim(fit$tau)[1]
nknots    <- dim(fit$knots)[2]
d11       <- rdist(S.p, S.p)
d22       <- rdist(S.o, S.o)
diag(d11) <- 0
diag(d22) <- 0
d12       <- rdist(S.p, S.o)
cov.model <- "matern"
x.beta    <- matrix(0, ns, nt)
taug      <- matrix(0, ns, nt)
zg        <- matrix(0, ns, nt)
g         <- matrix(0, ns, nt)

# storage
y.pred    <- array(0, c(5000, np, nt))

set.seed(1)
for (i in 1:nreps) {
  # get values for current iteration from mcmc
  rho   <- fit$rho[i]
  nu    <- fit$nu[i]
  gamma <- fit$gamma[i]
  beta  <- fit$beta[i, ]
  tau   <- fit$tau[i, , ]
  knots <- fit$knots[i, , , ]
  z     <- matrix(0, nknots, nt)  # non-skew
  y     <- fit$y[i, , ]  # want to use imputed y not true y
  lambda.1 <- 0  # non-skew

  # precision matrix
  C <- gamma * simple.cov.sp(D=d22, sp.type=cov.model, sp.par=c(1, rho),
                             error.var=0, smoothness=nu, finescale.var=0)
  diag(C) <- 1
  prec <- chol2inv(chol(C))

  # update x.beta and taug
  for (t in 1:nt) {
    x.beta[, t] <- X.o[, t, ] %*% beta
    g[, t]      <- mem(S.o, knots[, , t])
    taug[, t]   <- tau[g[, t], t]
    zg[, t]     <- z[g[, t], t]
  }

  mu  <- x.beta + lambda.1 * zg
  res <- y - mu

  y.pred[i, , ] <- predictY(d11=d11, d12=d12, cov.model=cov.model, rho=rho,
                            nu=nu, gamma=gamma, res=res, beta=beta, tau=tau,
                            taug=taug, z=z, prec=prec, lambda.1=lambda.1,
                            s.pred=S.p, x.pred=X.p, knots=knots)

  if (i %% 500 == 0) {
    print(paste("Iter", i))
  }
}
save(y.pred, file=outputfile)