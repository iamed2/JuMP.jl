#  Copyright 2015, Iain Dunning, Joey Huchette, Miles Lubin, and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.
#############################################################################
# JuMP
# An algebraic modelling langauge for Julia
# See http://github.com/JuliaOpt/JuMP.jl
#############################################################################

# Overloads
#
# Different objects that must all interact:
# 1. Number
# 2. Variable
# 3. AffExpr
# 4. QuadExpr

# Number
# Number--Number obviously already taken care of!
# Number--Variable
(+)(lhs::Number, rhs::Variable) = AffExpr([rhs],[+1.],convert(Float64,lhs))
(-)(lhs::Number, rhs::Variable) = AffExpr([rhs],[-1.],convert(Float64,lhs))
(*)(lhs::Number, rhs::Variable) = AffExpr([rhs],[convert(Float64,lhs)], 0.)
# Number--GenericAffExpr
(+)(lhs::Number, rhs::GenericAffExpr) = GenericAffExpr(copy(rhs.vars),copy(rhs.coeffs),lhs+rhs.constant)
(-)(lhs::Number, rhs::GenericAffExpr) = GenericAffExpr(copy(rhs.vars),    -rhs.coeffs ,lhs-rhs.constant)
(*)(lhs::Number, rhs::GenericAffExpr) = GenericAffExpr(copy(rhs.vars),[lhs*rhs.coeffs[i] for i=1:length(rhs.coeffs)],lhs*rhs.constant)
# Number--QuadExpr
(+)(lhs::Number, rhs::QuadExpr) = QuadExpr(copy(rhs.qvars1),copy(rhs.qvars2),copy(rhs.qcoeffs),lhs+rhs.aff)
(-)(lhs::Number, rhs::QuadExpr) = QuadExpr(copy(rhs.qvars1),copy(rhs.qvars2),    -rhs.qcoeffs ,lhs-rhs.aff)
(*)(lhs::Number, rhs::QuadExpr) = QuadExpr(copy(rhs.qvars1),copy(rhs.qvars2), lhs*rhs.qcoeffs ,lhs*rhs.aff)

# This is not well defined if variable types are different, but needed to avoid ambiguities
(+)(lhs::GenericAffExpr, rhs::GenericAffExpr) = (+)(promote(lhs,rhs)...)
(-)(lhs::GenericAffExpr, rhs::GenericAffExpr) = (-)(promote(lhs,rhs)...)

# Variable
(+)(lhs::Variable) = lhs
(-)(lhs::Variable) = AffExpr([lhs],[-1.0],0.0)
(*)(lhs::Variable) = lhs
# Variable--Number
(+)(lhs::Variable, rhs::Number) = (+)( rhs,lhs)
(-)(lhs::Variable, rhs::Number) = (+)(-rhs,lhs)
(*)(lhs::Variable, rhs::Number) = (*)(rhs,lhs)
(/)(lhs::Variable, rhs::Number) = (*)(1./rhs,lhs)
# Variable--Variable
(+)(lhs::Variable, rhs::Variable) = AffExpr([lhs,rhs], [1.,+1.], 0.)
(-)(lhs::Variable, rhs::Variable) = AffExpr([lhs,rhs], [1.,-1.], 0.)
(*)(lhs::Variable, rhs::Variable) = QuadExpr([lhs],[rhs],[1.],AffExpr(Variable[],Float64[],0.))
# Variable--AffExpr
(+){CoefType,VarType}(lhs::VarType, rhs::GenericAffExpr{CoefType,VarType}) =
    GenericAffExpr{CoefType,VarType}(vcat(rhs.vars,lhs),vcat( rhs.coeffs,one(CoefType)), rhs.constant)
(-){CoefType,VarType}(lhs::VarType, rhs::GenericAffExpr{CoefType,VarType}) =
    GenericAffExpr{CoefType,VarType}(vcat(rhs.vars,lhs),vcat(-rhs.coeffs,one(CoefType)),-rhs.constant)
function (*)(lhs::Variable, rhs::AffExpr)
    n = length(rhs.vars)
    if rhs.constant != 0.
        ret = QuadExpr([lhs for i=1:n],copy(rhs.vars),copy(rhs.coeffs),AffExpr([lhs], [rhs.constant], 0.))
    else
        ret = QuadExpr([lhs for i=1:n],copy(rhs.vars),copy(rhs.coeffs),zero(AffExpr))
    end
end
(/)(lhs::Variable, rhs::AffExpr) = error("Cannot divide a variable by an affine expression")
# Variable--QuadExpr
(+)(v::Variable, q::QuadExpr) = QuadExpr(copy(q.qvars1),copy(q.qvars2),copy(q.qcoeffs),v+q.aff)
(-)(v::Variable, q::QuadExpr) = QuadExpr(copy(q.qvars1),copy(q.qvars2),    -q.qcoeffs ,v-q.aff)

# AffExpr (GenericAffExpr)
(+)(lhs::GenericAffExpr) = lhs
(-)(lhs::GenericAffExpr) = GenericAffExpr(lhs.vars, -lhs.coeffs, -lhs.constant)
(*)(lhs::GenericAffExpr) = lhs
# AffExpr--Number
(+)(lhs::GenericAffExpr, rhs::Number) = (+)(+rhs,lhs)
(-)(lhs::GenericAffExpr, rhs::Number) = (+)(-rhs,lhs)
(*)(lhs::GenericAffExpr, rhs::Number) = (*)(rhs,lhs)
(/)(lhs::GenericAffExpr, rhs::Number) = (*)(1.0/rhs,lhs)
function (^)(lhs::Union(Variable,AffExpr), rhs::Integer)
    rhs == 2 || error("Only exponents of 2 are currently supported. Are you trying to build a nonlinear problem? Make sure you use @addNLConstraint/@setNLObjective.")
    return lhs*lhs
end
(^)(lhs::Union(Variable,AffExpr), rhs::Number) = error("Only exponents of 2 are currently supported. Are you trying to build a nonlinear problem? Make sure you use @addNLConstraint/@setNLObjective.")
# AffExpr--Variable
(+){CoefType,VarType}(lhs::GenericAffExpr{CoefType,VarType}, rhs::VarType) = (+)(rhs,lhs)
(-){CoefType,VarType}(lhs::GenericAffExpr{CoefType,VarType}, rhs::VarType) = GenericAffExpr{CoefType,VarType}(vcat(lhs.vars,rhs),vcat(lhs.coeffs,-one(CoefType)),lhs.constant)
(*)(lhs::AffExpr, rhs::Variable) = (*)(rhs,lhs)
(/)(lhs::AffExpr, rhs::Variable) = error("Cannot divide affine expression by a variable")
# AffExpr--AffExpr
(+){T<:GenericAffExpr}(lhs::T, rhs::T) = GenericAffExpr(vcat(lhs.vars,rhs.vars),vcat(lhs.coeffs, rhs.coeffs),lhs.constant+rhs.constant)
(-){T<:GenericAffExpr}(lhs::T, rhs::T) = GenericAffExpr(vcat(lhs.vars,rhs.vars),vcat(lhs.coeffs,-rhs.coeffs),lhs.constant-rhs.constant)
function (*)(lhs::AffExpr, rhs::AffExpr)
    ret = QuadExpr(Variable[],Variable[],Float64[],AffExpr(Variable[],Float64[],0.))

    # Quadratic terms
    n = length(lhs.coeffs)
    m = length(rhs.coeffs)
    sizehint!(ret.qvars1, n*m)
    sizehint!(ret.qvars2, n*m)
    sizehint!(ret.qcoeffs, n*m)
    for i = 1:n
        for j = 1:m
            push!(ret.qvars1,  lhs.vars[i])
            push!(ret.qvars2,  rhs.vars[j])
            push!(ret.qcoeffs, lhs.coeffs[i]*rhs.coeffs[j])
        end
    end

    # Try to preallocate space for aff
    if lhs.constant != 0 && rhs.constant != 0
        sizehint!(ret.aff.vars, n+m)
        sizehint!(ret.aff.coeffs, n+m)
    elseif lhs.constant != 0
        sizehint!(ret.aff.vars, n)
        sizehint!(ret.aff.coeffs, n)
    elseif rhs.constant != 0
        sizehint!(ret.aff.vars, m)
        sizehint!(ret.aff.coeffs, m)
    end

    # [LHS constant] * RHS
    if lhs.constant != 0
        c = lhs.constant
        for j = 1:m
            push!(ret.aff.vars,   rhs.vars[j])
            push!(ret.aff.coeffs, rhs.coeffs[j] * c)
        end
        ret.aff.constant += c * rhs.constant
    end

    # [RHS constant] * LHS
    if rhs.constant != 0
        c = rhs.constant
        for i = 1:n
            push!(ret.aff.vars,   lhs.vars[i])
            push!(ret.aff.coeffs, lhs.coeffs[i] * c)
        end
        # Don't do the following line
        #ret.aff.constant += c * lhs.constant
        # If lhs.constant is 0, its a waste of time
        # If lhs.constant is non-zero, its already done
    end

    return ret
end
# AffExpr--QuadExpr
(+)(a::AffExpr, q::QuadExpr) = QuadExpr(copy(q.qvars1),copy(q.qvars2),copy(q.qcoeffs),a+q.aff)
(-)(a::AffExpr, q::QuadExpr) = QuadExpr(copy(q.qvars1),copy(q.qvars2),    -q.qcoeffs ,a-q.aff)


# QuadExpr
(+)(lhs::QuadExpr) = lhs
(-)(lhs::QuadExpr) = 0.0-lhs
(*)(lhs::QuadExpr) = lhs
# QuadExpr--Number
(+)(lhs::QuadExpr, rhs::Number) = (+)(+rhs,lhs)
(-)(lhs::QuadExpr, rhs::Number) = (+)(-rhs,lhs)
(*)(lhs::QuadExpr, rhs::Number) = (*)(rhs,lhs)
(/)(lhs::QuadExpr, rhs::Number) = (*)(1.0/rhs,lhs)
# QuadExpr--Variable
(+)(q::QuadExpr, v::Variable) = (+)(v,q)
(-)(q::QuadExpr, v::Variable) = QuadExpr(copy(q.qvars1),copy(q.qvars2),copy(q.qcoeffs),q.aff-v)
(*)(q::QuadExpr, v::Variable) = error("Cannot multiply a quadratic expression by a variable")
(/)(q::QuadExpr, v::Variable) = error("Cannot divide a quadratic expression by a variable")
# QuadExpr--AffExpr
(+)(q::QuadExpr, a::AffExpr) = QuadExpr(copy(q.qvars1),copy(q.qvars2),copy(q.qcoeffs),q.aff+a)
(-)(q::QuadExpr, a::AffExpr) = QuadExpr(copy(q.qvars1),copy(q.qvars2),copy(q.qcoeffs),q.aff-a)
(*)(q::QuadExpr, a::AffExpr) = error("Cannot multiply a quadratic expression by an aff. expression")
(/)(q::QuadExpr, a::AffExpr) = error("Cannot divide a quadratic expression by an aff. expression")
# QuadExpr--QuadExpr
(+)(q1::QuadExpr, q2::QuadExpr) = QuadExpr( vcat(q1.qvars1, q2.qvars1),     vcat(q1.qvars2, q2.qvars2),
                                            vcat(q1.qcoeffs, q2.qcoeffs),   q1.aff + q2.aff)
(-)(q1::QuadExpr, q2::QuadExpr) = QuadExpr( vcat(q1.qvars1, q2.qvars1),     vcat(q1.qvars2, q2.qvars2),
                                            vcat(q1.qcoeffs, -q2.qcoeffs),  q1.aff - q2.aff)

# (==)(lhs::AffExpr,rhs::AffExpr) = (lhs.vars == rhs.vars) && (lhs.coeffs == rhs.coeffs) && (lhs.constant == rhs.constant)
# (==)(lhs::QuadExpr,rhs::QuadExpr) = (lhs.qvars1 == rhs.qvars1) && (lhs.qvars2 == rhs.qvars2) && (lhs.qcoeffs == rhs.qcoeffs) && (lhs.aff == rhs.aff)

_deprecate_comparisons(sgn) =
    Base.warn_once("The comparison operator $sgn has been deprecated for constructing constraints. Use the macro form @addConstraint instead.")

# LinearConstraint
# Number--???
for (sgn, osgn) in ( (:<=,:>=), (:(==),:(==)), (:>=,:<=) )
    for typ in (:Variable, :AffExpr, :QuadExpr)
        @eval $(sgn)(lhs::Number, rhs::$(typ)) = $(osgn)(rhs, lhs)
    end
    # Variable--???
    for typ in (:Number, :Variable, :AffExpr, :QuadExpr)
        @eval $(sgn)(lhs::Variable, rhs::$(typ)) = $(sgn)(lhs-rhs, 0.0)
    end
end
# AffExpr--???
function (<=)(lhs::AffExpr, rhs::Number)
    _deprecate_comparisons(:(<=))
    LinearConstraint(lhs,-Inf,rhs-lhs.constant)
end
function (==)(lhs::AffExpr, rhs::Number)
    _deprecate_comparisons(:(==))
    LinearConstraint(lhs,rhs-lhs.constant,rhs-lhs.constant)
end
function (>=)(lhs::AffExpr, rhs::Number)
    _deprecate_comparisons(:(>=))
    LinearConstraint(lhs,rhs-lhs.constant,Inf)
end
for sgn in (:<=, :(==), :>=)
    for typ in (:Variable, :AffExpr, :QuadExpr)
        @eval $(sgn)(lhs::AffExpr, rhs::$(typ)) = $(sgn)(lhs-rhs, 0.0)
    end
end
# There's no easy way to allow operator overloads for range constraints.
# Use macros instead.

# QuadConstraint
# QuadConstraint--Number
for sgn in (:<=, :(==), :>=)
    @eval begin
        function $(sgn)(lhs::QuadExpr, rhs::Number)
            _deprecate_comparisons($sgn)
            QuadConstraint( QuadExpr(copy(lhs.qvars1), copy(lhs.qvars2), lhs.qcoeffs,lhs.aff - rhs), $(quot(sgn)))
        end
    end
    for typ in (:Variable, :AffExpr, :QuadExpr)
        @eval $(sgn)(lhs::QuadExpr, rhs::$(typ)) = $(sgn)(lhs-rhs, 0)
    end
end

#############################################################################
# High-level operators
# Currently supported
#  - sum
#  - dot
#############################################################################

typealias JuMPTypes Union(Variable,AffExpr,QuadExpr)

Base.sum(j::JuMPArray) = sum(j.innerArray)
Base.sum(j::JuMPDict)  = sum(values(j.tupledict))
Base.sum(j::JuMPArray{Variable}) = AffExpr(vec(j.innerArray), ones(length(j.innerArray)), 0.0)
Base.sum(j::JuMPDict{Variable})  = AffExpr(collect(values(j.tupledict)), ones(length(j.tupledict)), 0.0)
Base.sum(j::Array{Variable}) = AffExpr(vec(j), ones(length(j)), 0.0)
function Base.sum{S,T}(affs::Array{GenericAffExpr{S,T}})
    new_aff = zero(GenericAffExpr{S,T})
    for aff in affs
        append!(new_aff, aff)
    end
    return new_aff
end

if VERSION < v"0.4-"
    export vecdot
    vecdot{T,S,N}(x::Array{T,N},y::Array{S,N}) = _dot(x,y)
else
    import Base.vecdot
end

_dot_depr() = warn("dot is deprecated for multidimensional arrays. Use vecdot instead.")
Base.dot{T,S,N}(lhs::Array{T,N}, rhs::JuMPArray{S,N})    = begin _dot_depr(); vecdot(lhs,rhs); end
Base.dot{T,S,N}(lhs::JuMPArray{T,N},rhs::Array{S,N})     = begin _dot_depr(); vecdot(lhs,rhs); end
Base.dot{T,S,N}(lhs::JuMPArray{T,N},rhs::JuMPArray{S,N}) = begin _dot_depr(); vecdot(lhs,rhs); end

Base.dot{T,S}(lhs::OneIndexedArray{T,1},rhs::OneIndexedArray{S,1}) = _dot(lhs.innerArray, rhs.innerArray)
Base.dot{T,S}(lhs::OneIndexedArray{T,1},rhs::Vector{S}) = _dot(lhs.innerArray, rhs)
Base.dot{T,S}(lhs::Vector{T},rhs::OneIndexedArray{S,1}) = _dot(lhs, rhs.innerArray)
Base.dot{T<:JuMPTypes,S}(lhs::Vector{T},rhs::Vector{S}) = _dot(lhs,rhs)
Base.dot{T<:JuMPTypes,S<:JuMPTypes}(lhs::Vector{T},rhs::Vector{S}) = _dot(lhs,rhs)
Base.dot{T,S<:JuMPTypes}(lhs::Vector{T},rhs::Vector{S}) = _dot(lhs,rhs)

# TODO: qualify Base.vecdot once v0.3 support is dropped
vecdot{T,S,N}(lhs::OneIndexedArray{T,N},rhs::OneIndexedArray{S,N}) = _dot(lhs.innerArray, rhs.innerArray)
vecdot{T,S,N}(lhs::OneIndexedArray{T,N},rhs::Array{S,N}) = _dot(lhs.innerArray, rhs)
vecdot{T,S,N}(lhs::Array{T,N},rhs::OneIndexedArray{S,N}) = _dot(lhs, rhs.innerArray)
vecdot{T<:JuMPTypes,S,N}(lhs::Array{T,N},rhs::Array{S,N}) = _dot(lhs,rhs)
vecdot{T<:JuMPTypes,S<:JuMPTypes,N}(lhs::Array{T,N},rhs::Array{S,N}) = _dot(lhs,rhs)
vecdot{T,S<:JuMPTypes,N}(lhs::Array{T,N},rhs::Array{S,N}) = _dot(lhs,rhs)

function _dot{T,S}(lhs::Array{T}, rhs::Array{S})
    size(lhs) == size(rhs) || error("Incompatible dimensions")
    ret = zero(one(T)*one(S))
    for (x,y) in zip(lhs,rhs)
        ret = addToExpression(ret, x, y)
    end
    ret
end

###############################################################################
# A bunch of operator junk to make matrix multiplication and friends act
# reasonably sane with JuMP types

typealias JuMPTypes Union(Variable,AffExpr,QuadExpr)

Base.promote_rule{R<:Real}(::Type{Variable},::Type{R}       ) = AffExpr
Base.promote_rule         (::Type{Variable},::Type{AffExpr} ) = AffExpr
Base.promote_rule         (::Type{Variable},::Type{QuadExpr}) = QuadExpr
Base.promote_rule{R<:Real}(::Type{AffExpr}, ::Type{R}       ) = AffExpr
Base.promote_rule         (::Type{AffExpr}, ::Type{QuadExpr}) = QuadExpr
Base.promote_rule{R<:Real}(::Type{QuadExpr},::Type{R}       ) = QuadExpr
_throw_transpose_error() = error("Transpose not currently implemented for JuMPArrays with arbitrary index sets.")

Base.transpose(x::OneIndexedArray)  = transpose(x.innerArray)
Base.transpose(x::JuMPArray)  = _throw_transpose_error()
Base.ctranspose(x::OneIndexedArray) = ctranspose(x.innerArray)
Base.ctranspose(x::JuMPArray)  = _throw_transpose_error()

# Can remove the following code once == overloading is removed
_isequal{T,S}(x::T,y::S) = error("Internal error: called _isequal(::$T,::$S)")
_isequal(x::Variable,y::Variable) = (x.m == y.m) & (x.col == y.col)
function _isequal{T<:GenericAffExpr}(x::T,y::T)
    x.constant == y.constant || return false
    n = length(x.vars)
    if !(n == length(y.vars) &&
         n == length(x.coeffs) &&
         n == length(y.coeffs))
        return false
    end
    for i in 1:n
        if !_isequal(x.vars[i], y.vars[i])
            return false
        end
        if x.coeffs[i] != y.coeffs[i]
            return false
        end
    end
    true
end
function _isequal{T<:GenericQuadExpr}(x::T,y::T)
    if !_isequal(x.aff, y.aff)
        return false
    end
    n = length(x.qvars1)
    if !(n == length(y.qvars1) &&
         n == length(x.qvars2) &&
         n == length(y.qvars2) &&
         n == length(x.qcoeffs) &&
         n == length(y.qcoeffs))
        return false
    end
    for i in 1:n
        if !_isequal(x.qvars1[i], y.qvars1[i])
            return false
        end
        if !_isequal(x.qvars2[i], y.qvars2[i])
            return false
        end
        if x.qcoeffs[i] != y.qcoeffs[i]
            return false
        end
    end
    true
end

function Base.issym{T<:JuMPTypes}(x::Matrix{T})
    (n = size(x,1)) == size(x,2) || return false
    for i in 1:n, j in (i+1):n
        _isequal(x[i,j], x[j,i]) || return false
    end
    true
end

# Special-case because the the base version wants to do fill!(::Array{Variable}, zero(AffExpr))
Base.diagm(x::Vector{Variable}) = diagm(convert(Vector{AffExpr}, x))

###############
# The _multiply!(buf,y,z) adds the results of y*z into the buffer buf. No bounds/size
# checks are performed; it is expected that the caller has done this, has ensured
# that the eltype of buf is appropriate, and has zeroed the elements of buf (if desired).

function _multiply!(ret, A, x)
    m, n = size(A,1), size(A,2)
    for i in 1:m, j in 1:n
        ret[i] += A[i,j] * x[j]
    end
    return ret
end

_sizehint_expr!(q::GenericAffExpr, n::Int) = begin
        sizehint!(q.vars,   length(q.vars)   + n)
        sizehint!(q.coeffs, length(q.coeffs) + n)
        nothing
end

_sizehint_expr!(q::GenericQuadExpr, n::Int) = begin
        sizehint!(q.qvars1,  length(q.qvars1)  + n)
        sizehint!(q.qvars2,  length(q.qvars2)  + n)
        sizehint!(q.qcoeffs, length(q.qcoeffs) + n)
        _sizehint_expr!(q.aff, n)
        nothing
end
_sizehint_expr!(q, n) = nothing

function _multiply!{T<:Union(GenericAffExpr,GenericQuadExpr)}(ret::Array{T}, lhs, rhs)
    m, n = size(lhs,1), size(lhs,2)
    r, s = size(rhs,1), size(rhs,2)
    p, q = size(ret,1), size(ret,2)
    for i in 1:m, j in 1:s
        q = zero(T)
        _sizehint_expr!(q, n)
        for k in 1:n
            tmp = convert(T, lhs[i,k]*rhs[k,j])
            append!(q, tmp)
        end
        ret[i,j] = q
    end
    ret
end

function _multiply!{T<:Union(GenericAffExpr,GenericQuadExpr)}(ret::Array{T}, lhs::SparseMatrixCSC, rhs)
    m, n = size(lhs,1), size(lhs,2)
    r, s = size(rhs,1), size(rhs,2)
    p, q = size(ret,1), size(ret,2)
    for i in 1:m, j in 1:s
        q = zero(T)
        _sizehint_expr!(q, n)
        for k in lhs.colptr[i]:lhs.colptr[i+1]
            tmp = convert(T, lhs.nzval[k]*rhs[lhs.rowval[k],j])
            append!(q, tmp)
        end
        ret[i,j] = q
    end
    ret
end

# Not sure how/why you'd make a sparse matrix with Variables...
_multiply!{T<:Union(GenericAffExpr,GenericQuadExpr)}(ret::Array{T}, lhs::SparseMatrixCSC, rhs::SparseMatrixCSC) =
    _multiply!(ret, lhs, full(rhs))

# Kind of hacky that this relies on commutativity...
function _multiply!{T<:Union(GenericAffExpr,GenericQuadExpr)}(ret::Array{T}, lhs, rhs::SparseMatrixCSC)
    tmp = Array(T, size(ret,2), size(ret,1))
    _multiply!(tmp, rhs', lhs')
    copy!(ret, tmp')
    ret
end

(*)(lhs::AbstractArray, rhs::OneIndexedArray) = (*)(lhs, rhs.innerArray)
(*)(lhs::OneIndexedArray, rhs::AbstractArray) = (*)(lhs.innerArray, rhs)
(*)(lhs::OneIndexedArray, rhs::OneIndexedArray) = (*)(lhs.innerArray, rhs.innerArray)

# Don't do size checks here in _return_array, defer that to (*)
function _return_array{R,S}(A::AbstractArray{R}, x::AbstractArray{S,1})
    Q = (R <: JuMPTypes && S <: JuMPTypes) ? QuadExpr : AffExpr
    m = size(A,1)
    Array(Q, m)
end

function _return_array{R,S}(A::AbstractArray{R}, x::AbstractArray{S,2})
    Q = (R <: JuMPTypes && S <: JuMPTypes) ? QuadExpr : AffExpr
    m = size(A,1)
    s = size(x,2)
    Array(Q, m, s)
end

function (*){T<:JuMPTypes}(A::Array{T}, x::Union(Array,SparseMatrixCSC))
    m, n = size(A,1), size(A,2)
    r, s = size(x,1), size(x,2)
    n == r || error("Incompatible sizes")
    ret = _return_array(A, x)
    _multiply!(ret, A, x)
    ret
end

function (*){T<:JuMPTypes,R<:JuMPTypes}(A::Array{T}, x::Array{R})
    (T == QuadExpr || R == QuadExpr) && error("Cannot multiply two arrays of QuadExpr")
    m, n = size(A,1), size(A,2)
    r, s = size(x,1), size(x,2)
    n == r || error("Incompatible sizes")
    ret = _return_array(A, x)
    _multiply!(ret, A, x)
    ret
end

function (*){T<:JuMPTypes}(A::Union(Array,SparseMatrixCSC), x::Array{T})
    m, n = size(A,1), size(A,2)
    r, s = size(x,1), size(x,2)
    n == r || error("Incompatible sizes")
    ret = _return_array(A, x)
    _multiply!(ret, A, x)
    return ret
end

for op in [:+, :-, :*]; @eval begin
    $op{T<:JuMPTypes}(lhs::Number,rhs::AbstractArray{T}) = map(c->$op(lhs,c), full(rhs))
    $op{T<:JuMPTypes}(lhs::AbstractArray{T},rhs::Number) = map(c->$op(c,rhs), full(lhs))
    $op{T<:JuMPTypes}(lhs::T,rhs::AbstractArray) = map(c->$op(lhs,c), full(rhs))
    $op{T<:JuMPTypes}(lhs::AbstractArray,rhs::T) = map(c->$op(c,rhs), full(lhs))
    $op(lhs::Real,rhs::OneIndexedArray) = $op(lhs, rhs.innerArray)
    $op(lhs::OneIndexedArray,rhs::Real) = $op(lhs.innerArray, rhs)

    $op(lhs::OneIndexedArray, rhs::AbstractArray) = $op(lhs.innerArray, rhs)
    $op(lhs::AbstractArray, rhs::OneIndexedArray) = $op(lhs, rhs.innerArray)

    $op{T<:JuMPTypes}(lhs::AbstractArray{T},rhs::OneIndexedArray) = $op(lhs,rhs.innerArray)
    $op{T<:JuMPTypes}(lhs::OneIndexedArray,rhs::AbstractArray{T}) = $op(lhs.innerArray,rhs)
    $op(lhs::OneIndexedArray,rhs::OneIndexedArray) = $op(lhs.innerArray,rhs.innerArray)
end; end

# Special-case sparse matrix scalar multiplicaiton
(*){T<:JuMPTypes}(lhs::T, rhs::SparseMatrixCSC) =
    SparseMatrixCSC(rhs.m, rhs.n, copy(rhs.colptr), copy(rhs.rowval), lhs .* rhs.nzval)
(*){T<:JuMPTypes}(lhs::Number, rhs::SparseMatrixCSC{T}) = scale(rhs, lhs)
(*){T<:JuMPTypes}(lhs::JuMPTypes, rhs::SparseMatrixCSC{T}) =
    SparseMatrixCSC(rhs.m, rhs.n, copy(rhs.colptr), copy(rhs.rowval), lhs .* rhs.nzval)
(*){T<:JuMPTypes}(lhs::SparseMatrixCSC, rhs::T) =
    SparseMatrixCSC(lhs.m, lhs.n, copy(lhs.colptr), copy(lhs.rowval), lhs.nzval .* rhs)
(*){T<:JuMPTypes}(lhs::SparseMatrixCSC{T}, rhs::Number) = scale(lhs, rhs)
(*){T<:JuMPTypes}(lhs::SparseMatrixCSC{T}, rhs::JuMPTypes) =
    SparseMatrixCSC(lhs.m, lhs.n, copy(lhs.colptr), copy(lhs.rowval), lhs.nzval .* rhs)
# The following are primarily there for internal use in the macro code for @addConstraint
for op in [:(+), :(-)]; @eval begin
    function $op(lhs::Array{Variable},rhs::Array{Variable})
        (sz = size(lhs)) == size(rhs) || error("Incompatible sizes for $op: $sz $op $(size(rhs))")
        ret = Array(AffExpr, sz)
        map!($op, ret, lhs, rhs)
        ret
    end
end; end

(/){T<:JuMPTypes}(lhs::Array{T},rhs::Real) = map(c->$op(c,rhs), lhs)
(/)(lhs::OneIndexedArray,rhs::Real) = $op(lhs.innerArray, rhs)

for (dotop,op) in [(:.+,:+), (:.-,:-), (:.*,:*), (:./,:/)]
    @eval begin
        $dotop(lhs::Real,rhs::JuMPTypes) = $op(lhs,rhs)
        $dotop(lhs::JuMPTypes,rhs::Real) = $op(lhs,rhs)
        $dotop{T<:JuMPTypes}(lhs::Real,rhs::Array{T}) = map(c->$op(lhs,c), rhs)
        $dotop{T<:JuMPTypes}(lhs::Array{T},rhs::Real) = map(c->$op(c,rhs), lhs)
        $dotop(lhs::Real,rhs::OneIndexedArray) = $dotop(lhs, rhs.innerArray)
        $dotop(lhs::OneIndexedArray,rhs::Real) = $dotop(lhs.innerArray, rhs)
        $dotop{T<:JuMPTypes}(lhs::T,rhs::Array) = map(c->$op(lhs,c), rhs)
        $dotop{T<:JuMPTypes}(lhs::Array,rhs::T) = map(c->$op(c,rhs), lhs)

        $dotop{T<:JuMPTypes,N}(lhs::Array{T,N},rhs::OneIndexedArray) = $dotop(lhs,rhs.innerArray)
        $dotop{T<:JuMPTypes,N}(lhs::OneIndexedArray,rhs::Array{T,N}) = $dotop(lhs.innerArray,rhs)
        $dotop(lhs::OneIndexedArray,rhs::OneIndexedArray) = $dotop(lhs.innerArray,rhs.innerArray)
    end
end
(+){T<:JuMPTypes}(x::Array{T}) = x
(+)(x::OneIndexedArray) = x.innerArray
(-){N}(x::Array{Variable,N}) = (-)(convert(Array{AffExpr,N},x))
(-)(x::OneIndexedArray) = -x.innerArray
(*){T<:JuMPTypes}(x::Array{T}) = x
(*)(x::OneIndexedArray) = x.innerArray

###############################################################################
# Add nonlinear function fallbacks for JuMP built-in types
const op_hint = "Are you trying to build a nonlinear problem? Make sure you use @addNLConstraint/@setNLObjective."
for (func,_) in Calculus.symbolic_derivatives_1arg(), typ in [:Variable,:AffExpr,:QuadExpr]
    errstr = "$func is not defined for type $typ. $op_hint"
    @eval Base.($(quot(func)))(::$typ) = error($errstr)
end

*{T<:QuadExpr,S<:Union(Variable,AffExpr,QuadExpr)}(::T,::S) =
    error( "*(::$T,::$S) is not defined. $op_hint")
(*)(lhs::QuadExpr, rhs::QuadExpr) =
    error( "*(::QuadExpr,::QuadExpr) is not defined. $op_hint")
*{T<:QuadExpr,S<:Union(Variable,AffExpr,QuadExpr)}(::S,::T) =
    error( "*(::$S,::$T) is not defined. $op_hint")
/{S<:Union(Number,Variable,AffExpr,QuadExpr),T<:Union(Variable,AffExpr,QuadExpr)}(::S,::T) =
    error( "/(::$S,::$T) is not defined. $op_hint")
