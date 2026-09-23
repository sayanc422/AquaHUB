package com.aquashop.order;

import com.aquashop.order.api.InquiryDtos;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The bounds on a submission, without a database or a Spring context.
 *
 * <p>These run everywhere, unlike {@link TankInquiryTest}. The endpoint is
 * public and unauthenticated (ADR 0021), so what it refuses to accept is the
 * only input control that exists, and it should not need Postgres to be
 * checked.
 */
class InquiryRequestValidationTest {

    private static ValidatorFactory factory;
    private static Validator validator;

    @BeforeAll static void open() {
        factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @AfterAll static void close() {
        factory.close();
    }

    private static InquiryDtos.InquiryRequest req(String message, String email, String phone) {
        return new InquiryDtos.InquiryRequest(message, email, phone);
    }

    private static int violations(InquiryDtos.InquiryRequest r) {
        return validator.validate(r).size();
    }

    @Test
    void acceptsAPlausibleSubmission() {
        assertThat(violations(req(
                "120 litre planted tank, soft water. I want a school of cardinals and some "
                + "otos, and something that will not eat the shrimp.",
                "priya@example.com", "+91 98765 43210"))).isZero();
    }

    @Test
    void refusesAnEmptyMessage() {
        // The one case the form will actually hit: someone clicks submit
        // without typing. A blank enquiry is a row that costs a key-holding
        // decrypt to discover is worthless.
        assertThat(violations(req("   ", "priya@example.com", "9876543210"))).isEqualTo(1);
    }

    @Test
    void refusesProseInThePhoneField() {
        assertThat(violations(req("A tank", "priya@example.com", "call me maybe"))).isPositive();
    }

    @Test
    void refusesSomethingThatIsNotAnEmailAddress() {
        assertThat(violations(req("A tank", "priya-at-example", "9876543210"))).isEqualTo(1);
    }

    @Test
    void acceptsInternationalAndLocalPhoneShapes() {
        // Nothing here can tell a real number from a plausible one, and a
        // stricter regex would reject correct numbers to catch nothing.
        for (String phone : new String[] { "9876543210", "+919876543210", "+44 (20) 7123-4567",
                                           "033 2345 6789" }) {
            assertThat(violations(req("A tank", "priya@example.com", phone)))
                    .describedAs(phone).isZero();
        }
    }

    @Test
    void capsTheMessageSoAPublicEndpointCannotBeFedAMegabyte() {
        assertThat(violations(req("x".repeat(4001), "priya@example.com", "9876543210")))
                .isEqualTo(1);
        assertThat(violations(req("x".repeat(4000), "priya@example.com", "9876543210")))
                .isZero();
    }
}
