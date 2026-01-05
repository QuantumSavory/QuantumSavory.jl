abstract type AbstractMeasurement end

struct HomodyneMeasurement <: AbstractMeasurement
    angles::Vector{Real}
    squeeze::Real
end
HomodyneMeasurement(angles::Vector{<:Real}; squeeze = eps()) = HomodyneMeasurement(angles, squeeze)